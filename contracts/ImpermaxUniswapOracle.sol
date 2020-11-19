pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "./ImpermaxUniswapOracleStorage.sol";
import "./libraries/SafeMath.sol";
import "./libraries/SafeMath32.sol";
import "./libraries/UQ112x112.sol";
import "./interfaces/IUniswapV2Pair.sol";

//TODO ADD EVENTS

contract ImpermaxUniswapOracle is ImpermaxUniswapOracleStorage {
	using SafeMath for uint256;
	using SafeMath32 for uint32;
	using UQ112x112 for uint224;
		
	constructor() public {}	

	function toUint224(uint256 input) internal pure returns (uint224) {
		require(input <= uint224(-1), "ImpermaxUniswapOracle: UINT224_OVERFLOW");
		return uint224(input);
	}

	function toUint32(uint256 input) internal pure returns (uint32) {
		require(input <= uint32(-1), "ImpermaxUniswapOracle: UINT32_OVERFLOW");
		return uint32(input);
	}

	function toUint16(uint256 input) internal pure returns (uint16) {
		require(input <= uint16(-1), "ImpermaxUniswapOracle: UINT16_OVERFLOW");
		return uint16(input);
	}
	
	/**
	 * Conversion from uint224 to relative number given a reference
	 * The relative number is saved as Q8.24:
	 * - range: [0, 2**8 - 1]
	 * - resolution: 1 / 2**24
	 * Notice: it is required that ref / input < 2**8, or it will revert
	 */
	function toRelative(uint224 ref, uint224 input) internal pure returns (uint32) {
		return toUint32( uint256(input).mul(2**24).div(ref) );
	}
	function fromRelative(uint224 ref, uint input) internal pure returns (uint224) {
		return toUint224( uint256(ref).mul(input).div(2**24) );
	}
	
	// update priceReference if the relative difference from newPriceReference is more than 4 times
	function _updatePriceReference(Pair memory pair, uint224 newPriceReference) internal {
		if (uint256(pair.priceReference) * 4 < newPriceReference || pair.priceReference > uint256(newPriceReference) * 4) {
			require(newPriceReference != 0, "ImpermaxUniswapOracle: PRICE_REFERENCE_ZERO");
			uint224 oldPriceReference = pair.priceReference;
			pair.priceReference = newPriceReference;
			pair.referenceHasChanged = true;
			if (oldPriceReference == 0) return;
			for (uint32 i = 0; i < N; i++) {
				Interval memory interval = pair.intervals[i];
				interval.freshMA = toRelative(newPriceReference, fromRelative(oldPriceReference, interval.freshMA));
				interval.oldMA = toRelative(newPriceReference, fromRelative(oldPriceReference, interval.oldMA));
			}
		}
	}

	// in this function all prices are represented as relative to the priceReference
	function _updateIntervals(Pair memory pair, uint32 avg, uint32 T, uint32 priceLast, uint32 priceLastT) internal {
		for(uint32 i = 0; i < N; i++) {
			uint16 freshT = pair.intervals[i].freshT;
			uint32 freshMA = pair.intervals[i].freshMA;
			//first, update small Ks if priceLastT is big enough
			if (K(i) <= priceLastT) {
				pair.intervals[i] = Interval(0, 0, toUint16(K(i)), priceLast);
			}
			//then, apply the algorithm
			else if (T.add(freshT) < K(i)) {
				uint256 num = uint256(avg) * T + uint256(freshMA) * freshT;
				uint16 den = toUint16(T + freshT); //+ is safe
				pair.intervals[i].freshT = den;
				pair.intervals[i].freshMA = toUint32(num.div(den));
			}
			else if (T < K(i)) {
				pair.intervals[i] = Interval(toUint16(T), avg, freshT, freshMA);
			}
			else if (T <= K(i) * M) {
				pair.intervals[i] = Interval(0, 0, toUint16(T), avg);
			}
			else {
				pair.intervals[i] = Interval(0, 0, 0, 0);
			}
		}
	}
	
	function _update(Pair memory pair, uint256 priceCumulativeLast, uint32 reserveTimestamp, uint224 priceLast, uint32 blockTimestamp) internal {
		bool notInitialized = pair.priceReference == 0;
		if (notInitialized) { //executed only once for each pair
			uint32 T = blockTimestamp - reserveTimestamp;
			pair.priceCumulative = priceCumulativeLast + uint256(priceLast) * T;
			pair.blockTimestamp = blockTimestamp;
			_updatePriceReference(pair, priceLast);
			if (T == 0) return;
			uint32 priceLastRel = toRelative(pair.priceReference, priceLast);
			return _updateIntervals(pair, priceLastRel, T, priceLastRel, T);
		}

		// overflow is desired in the following
		uint32 priceLastT = blockTimestamp - reserveTimestamp;
		uint256 priceCumulative = priceCumulativeLast + uint256(priceLast) * priceLastT;
		uint32 T = blockTimestamp - pair.blockTimestamp;
		uint256 cumulativeDiff = priceCumulative - pair.priceCumulative;
		uint224 avg = uint224(cumulativeDiff.div(T));
		
		// update pair
		pair.priceCumulative = priceCumulative;
		pair.blockTimestamp = blockTimestamp;				
		_updatePriceReference(pair, priceLast);
		uint32 priceLastRel = toRelative(pair.priceReference, priceLast);
		uint32 avgRel = toRelative(pair.priceReference, avg);
		_updateIntervals(pair, avgRel, T, priceLastRel, priceLastT);
	}
	
	function _updateFromUniswapV2GivenPair(address uniswapV2Pair, Pair memory pair) internal {
		if (pair.blockTimestamp == getBlockTimestamp()) return;
		(uint112 reserve0, uint112 reserve1, uint32 reserveTimestamp) = IUniswapV2Pair(uniswapV2Pair).getReserves();
		if (pair.priceReference == 0) {
			//  initialize referenceInverted once, then it will never change
			pair.referenceInverted = (reserve0 > reserve1);
		}
		uint256 priceCumulativeLast;
		uint224 priceLast;
		if (!pair.referenceInverted) {
			priceCumulativeLast = IUniswapV2Pair(uniswapV2Pair).price0CumulativeLast();
			priceLast = UQ112x112.encode(reserve1).uqdiv(reserve0);
		} else {
			priceCumulativeLast = IUniswapV2Pair(uniswapV2Pair).price1CumulativeLast();
			priceLast = UQ112x112.encode(reserve0).uqdiv(reserve1);
		}
		_update(pair, priceCumulativeLast, reserveTimestamp, priceLast, getBlockTimestamp());
	}

	function _updateFromUniswapV2(address uniswapV2Pair) internal returns (Pair memory pair) {
		pair = _loadPair(uniswapV2Pair);
		_updateFromUniswapV2GivenPair(uniswapV2Pair, pair);
		_storePair(uniswapV2Pair, pair);
	}
	
	function _calculateResult(uint224 ref, Interval memory interval, uint32 Kmin) internal pure returns (uint32 T, uint224 price) {
		T = uint32(interval.freshT).add(interval.oldT);
		if (T < Kmin) return (0, 0);
		uint256 freshCum = uint256( fromRelative(ref, interval.freshMA) ) * interval.freshT;
		uint256 oldCum = uint256( fromRelative(ref, interval.oldMA) ) * interval.oldT;
		price = toUint224(freshCum.add(oldCum).div(T));
	}
	
	function _getFreshestResult(Pair memory pair, uint32 min, uint32 max) internal pure returns (uint32 T, uint224 price) {
		uint32 i = min;
		while (i <= max) {
			(T, price) = _calculateResult(pair.priceReference, pair.intervals[i], K(i));
			if(price != 0) return (T, price);
			i++;
		}
		return (0, 0); //could not calculate price, 0 is a signal
	}
	
	function _getStrongestResult(Pair memory pair, uint32 min, uint32 max) internal pure returns (uint32 T, uint224 price) {
		uint32 i = max;
		while (i >= min) {
			(T, price) = _calculateResult(pair.priceReference, pair.intervals[i], K(i));
			if(price != 0) return (T, price);
			i--;
		}
		return (0, 0); //could not calculate price, 0 is a signal
	}
	
	function _getResult(address uniswapV2Pair, uint32 min, uint32 max, bool freshest) internal returns (uint32 T, uint224 price) {
		require(min <= max, "PriceOracle: MIN_TOO_HIGH");
		require(max < N, "PriceOracle: MAX_TOO_HIGH");
		Pair memory pair = _updateFromUniswapV2(uniswapV2Pair);
		if (freshest) return _getFreshestResult(pair, min, max);
		else return _getStrongestResult(pair, min, max);
	}
	
	
	/*** External ***/
	
	function updateFromUniswapV2(address uniswapV2Pair) external {
		_updateFromUniswapV2(uniswapV2Pair);
	}
	
	function getResult(address uniswapV2Pair, uint32 min, uint32 max, bool freshest) external returns (uint32 T, uint224 price) {
		return _getResult(uniswapV2Pair, min, max, freshest);
	}	

	/*** Utilities ***/
	
	function getBlockTimestamp() internal view returns (uint32) {
		return uint32(block.timestamp % 2**32);
	}
}
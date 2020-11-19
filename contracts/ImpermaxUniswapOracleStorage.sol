pragma solidity ^0.5.16;

import "./libraries/SafeMath.sol";

contract ImpermaxUniswapOracleStorage {
	using SafeMath for uint256;

	uint32 internal constant N = 5; 
	uint32 internal constant M = 3;
	uint32 internal constant start = 240;
	
	/**
	 * The data of each pair is saved in 1024 bit
	 * priceCumulative is 256 bit
	 * priceReference is 224 bit, contained in tsRef
	 * blockTimestamp is 32 bit, contained in tsRef
	 * each freshMA and oldMA is saved in 32 bit as Q8.24 as value relative to priceReference
	 * each freshT and oldT is saved in 16 bit, note that the following is always true:
	 *     freshT, oldT <= 240 * 3**5 < 2**16
	 */
	struct PairStorageLowLevel {
		uint256 priceCumulative;
		uint256 referencePack;
		uint256 pack1;
		uint256 pack2;
	}
	mapping(address => PairStorageLowLevel) private pairs;

	struct Interval {
		uint16 freshT;
		uint32 freshMA;
		uint16 oldT;
		uint32 oldMA;
	}
	struct Pair {
		uint256 priceCumulative;
		uint32 blockTimestamp;
		uint224 priceReference;
		bool referenceInverted; //if false we use price0 (reserve1/reserve0), else we use price1 (reserve0/reserve1)
		bool referenceHasChanged;
		Interval[N] intervals;
	}

	function K(uint32 i) internal pure returns (uint32) {
		return start * M**i;
	}
	
	function _loadPair(address uniswapV2Pair) internal view returns (Pair memory pair) {
		PairStorageLowLevel memory pairMemoryLowLevel = pairs[uniswapV2Pair];
		//priceCumulative
		pair.priceCumulative = pairMemoryLowLevel.priceCumulative;
		//priceReference
		uint8 referenceMeta = uint8(pairMemoryLowLevel.referencePack / 2**224 % 2**8);
		if (referenceMeta % 2 == 1) pair.referenceInverted = true;
		pair.priceReference = uint224(pairMemoryLowLevel.referencePack % 2**224);
		//blockTimestamp
		pair.blockTimestamp = uint32(pairMemoryLowLevel.pack1 / 2**224);
		//intervals
		Interval memory interval1 = pair.intervals[0];
		Interval memory interval2 = pair.intervals[1];
		Interval memory interval3 = pair.intervals[2];
		Interval memory interval4 = pair.intervals[3];
		Interval memory interval5 = pair.intervals[4];
		interval1.freshT = uint16(pairMemoryLowLevel.pack1 % 2**16);
		interval2.freshT = uint16(pairMemoryLowLevel.pack1 / 2**16 % 2**16);
		interval3.freshT = uint16(pairMemoryLowLevel.pack2 % 2**16);
		interval4.freshT = uint16(pairMemoryLowLevel.pack2 / 2**16 % 2**16);
		interval5.freshT = uint16(pairMemoryLowLevel.pack1 / 2**192 % 2**16);
		interval1.oldT = uint16(pairMemoryLowLevel.pack1 / 2**32 % 2**16);
		interval2.oldT = uint16(pairMemoryLowLevel.pack1 / 2**48 % 2**16);
		interval3.oldT = uint16(pairMemoryLowLevel.pack2 / 2**32 % 2**16);
		interval4.oldT = uint16(pairMemoryLowLevel.pack2 / 2**48 % 2**16);
		interval5.oldT = uint16(pairMemoryLowLevel.pack1 / 2**208 % 2**16);
		interval1.freshMA = uint32(pairMemoryLowLevel.pack1 / 2**64 % 2**32);
		interval2.freshMA = uint32(pairMemoryLowLevel.pack1 / 2**96 % 2**32);
		interval3.freshMA = uint32(pairMemoryLowLevel.pack2 / 2**64 % 2**32);
		interval4.freshMA = uint32(pairMemoryLowLevel.pack2 / 2**96 % 2**32);
		interval5.freshMA = uint32(pairMemoryLowLevel.pack2 / 2**192 % 2**32);
		interval1.oldMA = uint32(pairMemoryLowLevel.pack1 / 2**128 % 2**32);
		interval2.oldMA = uint32(pairMemoryLowLevel.pack1 / 2**160 % 2**32);
		interval3.oldMA = uint32(pairMemoryLowLevel.pack2 / 2**128 % 2**32);
		interval4.oldMA = uint32(pairMemoryLowLevel.pack2 / 2**160 % 2**32);
		interval5.oldMA = uint32(pairMemoryLowLevel.pack2 / 2**224 % 2**32);
	}
	
	function _storePair(address uniswapV2Pair, Pair memory pair) internal {
		PairStorageLowLevel storage pairStorage = pairs[uniswapV2Pair];
		//priceCumulative
		pairStorage.priceCumulative = pair.priceCumulative;
		//priceReference
		if (pair.referenceHasChanged) {
			uint8 referenceMeta;
			if (pair.referenceInverted) referenceMeta += 1;
			pairStorage.referencePack = pair.priceReference + uint256(referenceMeta) * 2**224;
		}
		//intervals & blockTimestamp
		Interval memory interval1 = pair.intervals[0];
		Interval memory interval2 = pair.intervals[1];
		Interval memory interval3 = pair.intervals[2];
		Interval memory interval4 = pair.intervals[3];		
		Interval memory interval5 = pair.intervals[4];
		uint256 pack1; //avoid stack too deep error
		uint256 pack2;
		pack1 = uint256(pair.blockTimestamp) * 2**224 +
			uint256(interval1.freshT) 				+ uint256(interval2.freshT) * 2**16 + 
			uint256(interval1.oldT) * 2**32		+ uint256(interval2.oldT) * 2**48 + 
			uint256(interval1.freshMA) * 2**64	+ uint256(interval2.freshMA) * 2**96;
		pairStorage.pack1 = pack1 +
			uint256(interval1.oldMA) * 2**128		+ uint256(interval2.oldMA) * 2**160 +
			uint256(interval5.freshT) * 2**192	+ uint256(interval5.oldT) * 2**208;
		pack2 =
			uint256(interval3.freshT) 				+ uint256(interval4.freshT) * 2**16 + 
			uint256(interval3.oldT) * 2**32		+ uint256(interval4.oldT) * 2**48 + 
			uint256(interval3.freshMA) * 2**64	+ uint256(interval4.freshMA) * 2**96;
		pairStorage.pack2 = pack2 +
			uint256(interval3.oldMA) * 2**128		+ uint256(interval4.oldMA) * 2**160 +
			uint256(interval5.freshMA) * 2**192	+ uint256(interval5.oldMA) * 2**224;
	}
}
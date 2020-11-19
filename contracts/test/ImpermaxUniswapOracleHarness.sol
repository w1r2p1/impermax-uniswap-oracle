pragma solidity ^0.5.16;

import "../ImpermaxUniswapOracle.sol";

contract ImpermaxUniswapOracleHarness is ImpermaxUniswapOracle {

    uint32 internal blockTimestamp;
    
    constructor() public {}
    
    function harnessSetBlockTimestamp(uint32 _blockTimestamp) external {
        blockTimestamp = _blockTimestamp;
    }
    
	function getBlockTimestamp() internal view returns (uint32) {
	    if (blockTimestamp != 0) return blockTimestamp;
		return super.getBlockTimestamp();
	}
    
	function harnessGetStoredResult(address uniswapV2Pair, uint32 min, uint32 max, bool freshest) external view returns (uint32 T, uint224 price) {
		require(min <= max, "PriceOracle: MIN_TOO_HIGH");
		require(max < N, "PriceOracle: MAX_TOO_HIGH");
		Pair memory pair = _loadPair(uniswapV2Pair);
		if (freshest) return _getFreshestResult(pair, min, max);
		else return _getStrongestResult(pair, min, max);
	}
	
	/*** VIEW ***/

	function getPair(address uniswapV2Pair) external view returns (uint256 priceCumulative, uint32 blockTimestamp, uint224 priceReference) {
		Pair memory pair = _loadPair(uniswapV2Pair);
		return (pair.priceCumulative, pair.blockTimestamp, pair.priceReference);
	}
	
	function getInterval(address uniswapV2Pair, uint i) external view returns (uint32 freshT, uint224 freshMA, uint32 oldT, uint224 oldMA) {
		require(i < N, "PriceOracle: I_TOO_HIGH");
		Interval memory interval = _loadPair(uniswapV2Pair).intervals[i];
		return (interval.freshT, interval.freshMA, interval.oldT, interval.oldMA);
	}
}
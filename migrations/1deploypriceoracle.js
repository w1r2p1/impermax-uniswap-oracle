/*
 * This file deploy the contracts and contain some high level testing
 * This kind of testing is not to be considered exhaustive
 * The contracts of the Impermax Uniswap Oracle have never been tested properly yet
 */

const MockUniswapV2Pair = artifacts.require('MockUniswapV2Pair')
const PriceOracle = artifacts.require('ImpermaxUniswapOracleHarness')

const { expectRevert, time, BN } = require('@openzeppelin/test-helpers');

function uq112(n) {
	let den = 10e13;
	let num = Math.round(n*den);
	var len = Math.max(num.toString().length, den.toString().length);
	const MAX_LEN = 14;
	if(len > MAX_LEN){
		num = Math.round(num / Math.pow(10, len - MAX_LEN));
		den = Math.round(den / Math.pow(10, len - MAX_LEN));
	}
	let b = (new BN(2**28)).mul(new BN(2**28)).mul(new BN(2**28)).mul(new BN(2**28)).mul(new BN(num)).div(new BN(den));	
	return b;
}

const nDeb = (num) => num * 1;
const nDeb112 = (num) => (Math.round(num / 2**112 * 100) / 100).toFixed(2);
const nDeb32 = (num) => (Math.round(num / 2**32 * 100) / 100).toFixed(2);

let debug = {
	priceOracle: null,
	uniPair: null,
	printAll: async (address) => {
		const {blockTimestamp, priceCumulative, priceReference} = await debug.priceOracle.getPair(address);
		console.log()
		console.log("blockTs: " + nDeb(blockTimestamp) + "\tcumulative: " + nDeb112(priceCumulative) + "\tpriceReference: " + nDeb112(priceReference));
		for(i=0; i<5; i++){
			const {freshT, freshMA, oldT, oldMA} = await debug.priceOracle.getInterval(address, i);
			const {T, price} = await debug.priceOracle.harnessGetStoredResult(address, i, i, true);
			console.log("freshT: " + nDeb(freshT) + "\tfreshMA: " + nDeb32(freshMA) + "\toldT: " + nDeb(oldT) + "\toldMA: " + nDeb32(oldMA) + "\tresultT: " + nDeb(T) + "\tresultMA: " + nDeb112(price));
		}
		await debug.printPair();
	},
	printPair: async () => {
		const {_reserve0, _reserve1, _blockTimestampLast} = await debug.uniPair.getReserves();
		console.log("reserve0: " + nDeb(_reserve0) + "\treserve1: " + nDeb(_reserve1) + "\tblockTimestampLast: " + nDeb(_blockTimestampLast));
		const price0CumulativeLast = await debug.uniPair.price0CumulativeLast();
		console.log("priceCumulativeLast: " + nDeb112(price0CumulativeLast));
	},
}

module.exports = async function(deployer) {

	const address0 = "0x0000000000000000000000000000000000000000";
	
	await deployer.deploy(MockUniswapV2Pair, address0, address0);
	const uniPairA = await MockUniswapV2Pair.deployed();
	debug.uniPair = uniPairA;
	await deployer.deploy(MockUniswapV2Pair, address0, address0);
	const uniPairB = await MockUniswapV2Pair.deployed();
	await deployer.deploy(PriceOracle);
	const priceOracle = await PriceOracle.deployed();
	debug.priceOracle = priceOracle;
	
	//HIGH LEVEL TESTING
	
	await debug.printAll(uniPairA.address);
	
	await uniPairA.setPrice("0", uq112(2.5));
	await priceOracle.harnessSetBlockTimestamp("100");
	await priceOracle.updateFromUniswapV2(uniPairA.address);
	await debug.printAll(uniPairA.address);
	
	await uniPairA.setPrice("200", uq112(2.9));
	await priceOracle.harnessSetBlockTimestamp("300");
	await priceOracle.updateFromUniswapV2(uniPairA.address);
	await debug.printAll(uniPairA.address);
	
	await uniPairA.setPrice("400", uq112(2.7));
	await priceOracle.harnessSetBlockTimestamp("500");
	await priceOracle.updateFromUniswapV2(uniPairA.address);
	await debug.printAll(uniPairA.address);
	
	await uniPairA.setPrice("500", uq112(3));
	await uniPairA.setPrice("600", uq112(4.3));
	await priceOracle.harnessSetBlockTimestamp("750");
	await priceOracle.updateFromUniswapV2(uniPairA.address);
	await debug.printAll(uniPairA.address);
	
	await uniPairA.setPrice("800", uq112(12.8));
	await priceOracle.harnessSetBlockTimestamp("900");
	await priceOracle.updateFromUniswapV2(uniPairA.address);
	await debug.printAll(uniPairA.address);
	
	await uniPairA.setPrice("1000", uq112(8.6));
	await priceOracle.harnessSetBlockTimestamp("1100");
	await priceOracle.updateFromUniswapV2(uniPairA.address);
	await debug.printAll(uniPairA.address);
	
	await uniPairA.setPrice("1200", uq112(6.9));
	await priceOracle.harnessSetBlockTimestamp("1300");
	await priceOracle.updateFromUniswapV2(uniPairA.address);
	await debug.printAll(uniPairA.address);
	
	await uniPairA.setPrice("1400", uq112(3.3));
	await priceOracle.harnessSetBlockTimestamp("1500");
	await priceOracle.updateFromUniswapV2(uniPairA.address);
	await debug.printAll(uniPairA.address);
	
	await uniPairA.setPrice("2800", uq112(2.5));
	await priceOracle.harnessSetBlockTimestamp("3500");
	await priceOracle.updateFromUniswapV2(uniPairA.address);
	await debug.printAll(uniPairA.address);
	
	await uniPairA.setPrice("5600", uq112(1.7));
	await priceOracle.harnessSetBlockTimestamp("7500");
	await priceOracle.updateFromUniswapV2(uniPairA.address);
	await debug.printAll(uniPairA.address);
	
	await uniPairA.setPrice("7500", uq112(4));
	await priceOracle.harnessSetBlockTimestamp("8000");
	await priceOracle.updateFromUniswapV2(uniPairA.address);
	await debug.printAll(uniPairA.address);
	
	await uniPairA.setPrice("8030", uq112(1.2));
	await uniPairA.setPrice("8090", uq112(0.5));
	await uniPairA.setPrice("8120", uq112(1.2));
	await uniPairA.setPrice("8180", uq112(2.4));
	await uniPairA.setPrice("8230", uq112(0.5));
	await priceOracle.harnessSetBlockTimestamp("8300");
	await priceOracle.updateFromUniswapV2(uniPairA.address);
	await debug.printAll(uniPairA.address);
	
	await uniPairA.setPrice("9000", uq112(2.1));
	await priceOracle.harnessSetBlockTimestamp("9100");
	await priceOracle.updateFromUniswapV2(uniPairA.address);
	await debug.printAll(uniPairA.address);
}
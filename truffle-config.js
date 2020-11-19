module.exports = {
	networks: {
		development: {
			host: "127.0.0.1",	
			port: 7545,		
			network_id: "*",
			gasPrice: 2000,
		},
	},
	compilers: {
		solc: {
			version: "0.5.16",
			optimizer: {
				enabled: true,
				runs: 1000000
			},
		},
	},
	mocha: {
		enableTimeouts: false,
		timeout: 120000, // 2min
	},
};

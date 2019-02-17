var threshold = 10;
for (var i = 0; i < eth.accounts.length; i++) { 
	personal.unlockAccount(eth.accounts[i], "", 0); 
	if (web3.fromWei(eth.getBalance(eth.accounts[i]), "tether") < threshold / 2) {
	eth.sendTransaction({from:eth.coinbase, to:eth.accounts[i], value: web3.toWei(threshold, "tether")});
	}
}

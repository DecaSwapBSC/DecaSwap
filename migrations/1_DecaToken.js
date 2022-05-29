const token = artifacts.require("DecaToken");

module.exports = function(deployer, network, accounts) {

  const name = "DECA TOKEN";
  const symbol = "DECA";
  const totalSupply = 270000000;

  deployer.deploy(token, name, symbol, totalSupply, accounts[0]);
};

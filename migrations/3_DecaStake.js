const decaToken = artifacts.require("DecaToken");
const cornToken = artifacts.require("CornToken");
const DecaStake = artifacts.require("DecaStake");

module.exports = function (deployer, network, accounts) {

  const decaToken = "0x2ba63e81CF28DC82e81A6b31516323FFED2f3A25";
  const cornToken = "0x0B406B2F48862A2065045e6bCA1f34d766849976";

  deployer.deploy(DecaStake, decaToken, cornToken, accounts[0]);
};

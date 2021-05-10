const Link = artifacts.require("Link");
const eth = artifacts.require("ETH");

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(Link);
  await deployer.deploy(eth)
};

const { upgrades } = require("hardhat");
const hre = require("hardhat");

async function main() {
  // We get the contract to deploy
  // const marketplaceFactory = await hre.ethers.getContractFactory("Marketplace");
  // const marketplace = await upgrades.deployProxy(marketplaceFactory, ["0x35bCe40f61004a30527BbABF4b3240042B800A63", "0x83A54884bE4657706785D7309cf46B58FE5f6e8a"], {kind: "uups"});

  // await marketplace.deployed();

  // console.log("marketplace deployed to:", marketplace.address);

  // rinkeby address: 0x385f48cB0bc6F1E1E8Afc03B64E047734122Cc6c
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

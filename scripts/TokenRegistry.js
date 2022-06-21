const { upgrades } = require("hardhat");
const hre = require("hardhat");

async function main() {
  // We get the contract to deploy
  // const TokenRegistry = await hre.ethers.getContractFactory("TokenRegistry");
  // const tokenRegistry = await TokenRegistry.deploy();

  // await tokenRegistry.deployed();

  // console.log("tokenRegistry deployed to:", tokenRegistry.address);

  // rinkeby address: 0x35bCe40f61004a30527BbABF4b3240042B800A63

  await hre.run("verify:verify", {
    address: "0x35bCe40f61004a30527BbABF4b3240042B800A63",
    contract: "contracts/TokenRegistry.sol:TokenRegistry",
    constructorArguments: [
    ]
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

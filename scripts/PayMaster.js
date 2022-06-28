const { upgrades } = require("hardhat");
const hre = require("hardhat");

async function main() {
  // We get the contract to deploy
  // const paymasterFactory = await hre.ethers.getContractFactory("NaivePaymaster");
  // const paymaster = await paymasterFactory.deploy();

  // await paymaster.deployed();

  // console.log("paymaster deployed to:", paymaster.address);

  // // config paymaster. This should be replaced
  // await paymaster.setRelayHub("0x6650d69225CA31049DB7Bd210aE4671c0B1ca132");
  // await paymaster.setTrustedForwarder("0x83A54884bE4657706785D7309cf46B58FE5f6e8a");
  // await paymaster.setTarget("0xA29c5B0CB7EDeA13E14aC8170688a89d4D7eD717");

  // rinkeby address: 0xBaCB07678Ab8Fe8236cC6B52Fa8B96DFC278439B

  await hre.run("verify:verify", {
    address: "0xBaCB07678Ab8Fe8236cC6B52Fa8B96DFC278439B",
    contract: "contracts/NaivePaymaster.sol:NaivePaymaster",
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

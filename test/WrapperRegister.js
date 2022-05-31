const { expect } = require("chai");
const { parseEther, formatEther } = require("ethers/lib/utils");
const { ethers, upgrades } = require("hardhat");
const Web3HttpProvider = require( 'web3-providers-http');
const { Contract } = require("ethers");

describe("WrapperRegister TEST", function () {
  let registeryFactory;
  let wrapperFactory;
  let mockERC1155Factory;
  let mockERC721Factory;

  let registry;
  let mockERC721Wrapper;
  let mockERC721;
  let mockERC1155;

  let owner, other, author, curreny;
  before(async function() {
    [owner, other, author, curreny] = await ethers.getSigners();
    registeryFactory = await ethers.getContractFactory("WrappersRegistryV1");
    wrapperFactory = await ethers.getContractFactory("MockERC721Wrapper");
    mockERC1155Factory = await ethers.getContractFactory("MockERC1155");
    mockERC721Factory = await ethers.getContractFactory("MockERC721");

    await author.sendTransaction({
      to: owner.address,
      value: parseEther("1")
    })
  })

  beforeEach(async function() {
    mockERC1155 = await mockERC1155Factory.deploy();
    await mockERC1155.deployed();
   
    mockERC721 = await mockERC721Factory.deploy();
    await mockERC721.deployed();

    registry = await registeryFactory.deploy();
    await registry.deployed();

    mockERC721Wrapper = await wrapperFactory.deploy(mockERC721.address);
    await mockERC721Wrapper.deployed();

    await mockERC1155.mint(1, 4);
    await mockERC721.mint(1);

  })

  it("Wrapper is not registered", async function () {
    let a = await registry.isRegistered(mockERC721Wrapper.address)
...
  });

});

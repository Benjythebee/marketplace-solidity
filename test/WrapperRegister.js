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
  let accessControl;
  let owner, other, author, curreny;
  before(async function() {
    [owner, other, author, curreny] = await ethers.getSigners();
    let accessControlFactory = await ethers.getContractFactory("CryptovoxelsAccessControl");
    accessControl= await accessControlFactory.deploy();
    await accessControl.deployed();
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

    registry = await registeryFactory.deploy(accessControl.address);
    await registry.deployed();

    mockERC721Wrapper = await wrapperFactory.deploy(mockERC721.address);
    await mockERC721Wrapper.deployed();

    await mockERC1155.mint(1, 4);
    await mockERC721.mint(1);

  })

  it("AddressZero is set as index 0", async function () {
    let a = await registry.wrappersSize()
    let w = await registry.getWrapper(0)
    expect(a).to.be.equal(1)
    expect(w.implementation).to.be.equal(ethers.constants.AddressZero)
    expect(w.wrapper).to.be.equal(ethers.constants.AddressZero)
    expect(w.name_).to.be.equal('')
  });

  it("Wrapper is not registered", async function () {
    let a = await registry.isRegistered(mockERC721Wrapper.address)
    expect(a).to.be.false
  });

  it("Wrapper is registered", async function () {
    await registry.registerAs(mockERC721.address,mockERC721Wrapper.address,'ERC721')
    let a = await registry.isRegistered(mockERC721Wrapper.address)
    expect(a).to.be.true
    let len = await registry.wrappersSize()
    expect(len).to.be.equal(2)
  });

  it("Wrapper is registered -from...", async function () {
    await registry.registerAs(mockERC721.address,mockERC721Wrapper.address,'ERC721')

    let [id,impl,wrapper,name] = await registry.fromImplementationAddress(mockERC721.address)
    let [id2,impl2,wrapper2,name2] = await registry.fromName('ERC721')
  
    expect(wrapper).to.be.equal(mockERC721Wrapper.address)
    expect(impl).to.be.equal(mockERC721.address)
    expect(wrapper2).to.be.equal(mockERC721Wrapper.address)
  });

  it("Wrapper is unregistered", async function () {
    await registry.registerAs(mockERC721.address,mockERC721Wrapper.address,'ERC721')
    let a = await registry.isRegistered(mockERC721Wrapper.address)
    expect(a).to.be.true
    let [id,impl,wrapper,name] = await registry.fromName('ERC721')
    await registry.unregister(id)
    a = await registry.isRegistered(mockERC721Wrapper.address)
    expect(a).to.be.false
  });

  it("Wrapper is unregistered - register again", async function () {
    await registry.registerAs(mockERC721.address,mockERC721Wrapper.address,'ERC721')
    let a = await registry.isRegistered(mockERC721Wrapper.address)
    let [id,impl,wrapper,name] = await registry.fromName('ERC721')
    await registry.unregister(id)
    a = await registry.isRegistered(mockERC721Wrapper.address)
    expect(a).to.be.false


    // test if we can reregister same name - implementation
    await registry.registerAs(mockERC721.address,mockERC721Wrapper.address,'ERC721')
    let [id2,impl2,wrapper2,name2] = await registry.fromName('ERC721')
    expect(wrapper2).to.be.equal(mockERC721Wrapper.address)
    expect(impl2).to.be.equal(mockERC721.address)
  });
});

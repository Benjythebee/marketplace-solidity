const { expect } = require("chai");
const { parseEther, formatEther } = require("ethers/lib/utils");
const { ethers, upgrades } = require("hardhat");
const { RelayProvider } = require('@opengsn/provider')
const { GsnTestEnvironment } = require('@opengsn/dev' )
const Web3HttpProvider = require( 'web3-providers-http');
const { Contract } = require("ethers");

describe("Marketplace TEST", function () {
  let marketplaceFactory;
  let mockERC1155Factory;
  let mockERC721Factory;
  let tokenRegistryFactory;
  let mockERC20Factory;

  let marketplace;
  let mockERC1155;
  let mockERC721;
  let tokenRegistery;
  let wrapperRegistry; // wrapper registry to allow non-ERC721 non-ERC1155
  let mockNonERC721;// an ERC721-like contract but isn't ERC721
  let mockNonERC721Wrapper;// wrapper around the ERC721 std; (for easy testing)
  let accessControl;
  let mockERC20;
  let owner, other, author, curreny;
  before(async function() {
    [owner, other, author, curreny] = await ethers.getSigners();
    let accessControlFactory = await ethers.getContractFactory("CryptovoxelsAccessControl");
    accessControl= await accessControlFactory.deploy();
    await accessControl.deployed();
    let wrapperRegisteryFactory = await ethers.getContractFactory("WrappersRegistryV1");
    wrapperRegistry = await wrapperRegisteryFactory.deploy(accessControl.address);
    await wrapperRegistry.deployed();
    let mockNonERC721Factory = await ethers.getContractFactory("MockNonERC721");
    mockNonERC721 = await mockNonERC721Factory.deploy();
    await mockNonERC721.deployed();
    let wrapperFactory = await ethers.getContractFactory("MockNonERC721Wrapper");
    mockNonERC721Wrapper = await wrapperFactory.deploy(mockNonERC721.address);
    await mockNonERC721Wrapper.deployed();
    marketplaceFactory = await ethers.getContractFactory("Marketplace");
    mockERC1155Factory = await ethers.getContractFactory("MockERC1155");
    mockERC721Factory = await ethers.getContractFactory("MockERC721");
    tokenRegistryFactory = await ethers.getContractFactory("TokenRegistry");
    mockERC20Factory = await ethers.getContractFactory("MockERC20");
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

    tokenRegistery = await tokenRegistryFactory.deploy();
    await tokenRegistery.deployed();

    mockERC20 = await mockERC20Factory.deploy();
    await mockERC20.deployed();

    await mockERC1155.mint(1, 4);

    const fakeForwarder = mockERC1155.address

    marketplace = await upgrades.deployProxy(marketplaceFactory, [tokenRegistery.address,wrapperRegistry.address, fakeForwarder], { kind: "uups"});
    await marketplace.deployed();
    
    await tokenRegistery.register(mockERC20.address, "mock",18 ,"mock", {value: parseEther("20")});

    await mockERC1155.setApprovalForAll(marketplace.address, true)
  })

  // it("Should only let admin upgrade", async function () {
  //   let v2Factory = await ethers.getContractFactory("Marketplace2", other);
  //   await expect(upgrades.upgradeProxy(marketplace.address, v2Factory)).to.be.reverted;

  //   v2Factory = await ethers.getContractFactory("Marketplace2", owner);
  //   const v2 = await upgrades.upgradeProxy(marketplace.address, v2Factory);

  //   expect(await v2.name()).to.be.equal("Marketplace2");
  // });

  // it("Should only list ERC721 or ERC1155", async function () {
  //   await expect(marketplace.list(owner.address, 1, parseEther("2"), 1, mockERC20.address)).to.be.reverted;
  //  });

  // it("Should not list if the price is less than min price", async function () {
  //   await expect(marketplace.list(mockERC1155.address, 1, parseEther("0.0001"), 1, mockERC20.address)).to.be.revertedWith("Price less than minimum");
  // });
  
  // it("Should not list with quantity = 0", async function () {
  //   await expect(marketplace.list(mockERC1155.address, 1, parseEther("1"), 0, mockERC20.address)).to.be.revertedWith("Quantity is 0");
  //  });

  // it("Should not list when not insufficient balance", async function () {
  //   await expect(marketplace.list(mockERC1155.address, 1, parseEther("1"), 5, mockERC20.address)).to.be.revertedWith("insufficient balance");
  //  });
   
  // it("Should list NFT", async function () {
  //   await marketplace.list(mockERC1155.address, 1, parseEther("1"), 3, mockERC20.address);

  //   const id = ethers.utils.solidityKeccak256(["address", "address", "uint256"], [owner.address, mockERC1155.address, 1]);

  //   expect(await marketplace.isExistId(id)).to.be.equal(true);
  //   const listing = await marketplace.getListing(id, 0);

  //   expect(listing.seller).to.be.equal(owner.address);
  //   expect(listing.contractAddress).to.be.equal(mockERC1155.address);
  //   expect(listing.price).to.be.equal(parseEther("1"));
  //   expect(listing.quantity).to.be.equal(3);
  //   expect(listing.acceptedPayment).to.be.equal(mockERC20.address);
  //   expect(listing.tokenId).to.be.equal(1);
  //  });

  // it("Should buy the NFT with token", async function () {
  //   const id = ethers.utils.solidityKeccak256(["address", "address", "uint256"], [owner.address, mockERC1155.address, 1]);
  //   await expect(marketplace.connect(other).buyWithToken(id, 0, 1)).to.be.revertedWith("listing not avaialble");
  //   await marketplace.list(mockERC1155.address, 1, parseEther("1"), 3, mockERC20.address);

  //   mockAnotherERC20 = await mockERC20Factory.deploy();
  //   await mockAnotherERC20.deployed();

  //   await expect(marketplace.connect(other).buyWithToken(id, 0, 1)).to.be.reverted;

  //   mockERC20.transfer(other.address, parseEther("4"));
  //   mockERC20.connect(other).approve(marketplace.address, parseEther("4"));

  //   await expect(() => marketplace.connect(other).buyWithToken(id, 0, 1)).to.be.changeTokenBalance(mockERC20, owner, parseEther("1"));
  //   expect(await mockERC1155.balanceOf(other.address, 1)).to.be.equal(1);
  //   expect(await mockERC1155.balanceOf(owner.address,1)).to.be.equal(3)

  //   await marketplace.connect(other).buyWithToken(id, 0, 1);
  //   await expect(marketplace.connect(other).buyWithToken(id, 0, 2)).to.be.revertedWith("Quantity unavailable");
  // });

  // it("Should not buy the NFT with token when already sold", async function () {
  //   const id = ethers.utils.solidityKeccak256(["address", "address", "uint256"], [owner.address, mockERC1155.address, 1]);
  //   await marketplace.list(mockERC1155.address, 1, parseEther("1"), 3, mockERC20.address);

  //   mockERC20.transfer(other.address, parseEther("4"));
  //   mockERC20.connect(other).approve(marketplace.address, parseEther("4"));

  //   await marketplace.connect(other).buyWithToken(id, 0, 3);

  //   await expect(marketplace.connect(other).buyWithToken(id, 0, 1)).to.be.revertedWith("listing not avaialble");
  // });

  // it("Should buy the NFT with native asset", async function () {
  //   const id = ethers.utils.solidityKeccak256(["address", "address", "uint256"], [owner.address, mockERC1155.address, 1]);
  //   await expect(marketplace.buy(id, 0, 1, {value: parseEther("1")})).to.be.revertedWith("listing not avaialble");
  //   await marketplace.list(mockERC1155.address, 1, parseEther("1"), 3, ethers.constants.AddressZero);

  //   await expect(marketplace.connect(other).buy(id, 0, 1, {value: parseEther("0.9")})).to.be.reverted;

  //   await expect(() => marketplace.connect(other).buy(id, 0, 1, {value: parseEther("1")})).to.be.changeEtherBalance(owner, parseEther("1"));
  //   expect(await mockERC1155.balanceOf(other.address, 1)).to.be.equal(1);
  // });

    
  // it("Listing validity should behave accordingly", async function () {
  //   await marketplace.list(mockERC1155.address, 1, parseEther("1"), 3, ethers.constants.AddressZero);
  //   const id = ethers.utils.solidityKeccak256(["address", "address", "uint256"], [owner.address, mockERC1155.address, 1]);

  //   await mockERC1155.setApprovalForAll(marketplace.address, false)
  //   // the seller has not approved the contract to allow transfers, revert
  //   await expect(marketplace.connect(other).buy(id, 0, 1, {value: parseEther("1")})).to.be.revertedWith("Listing is invalid");

  //   // seller sets approval;
  //   await mockERC1155.setApprovalForAll(marketplace.address,true)

  //   await expect(() => marketplace.connect(other).buy(id, 0, 1, {value: parseEther("1")})).to.be.changeEtherBalance(owner, parseEther("1"));
  // });


  // it("Should not cancel the list when not owner", async function () {
  //   const id = ethers.utils.solidityKeccak256(["address", "address", "uint256"], [owner.address, mockERC1155.address, 1]);
  //   await expect(marketplace.cancelList(id, 0)).to.be.revertedWith("listing not avaialble");
  //   await marketplace.list(mockERC1155.address, 1, parseEther("1"), 3, mockERC20.address);

  //   await expect(marketplace.connect(other).cancelList(id, 0)).to.be.revertedWith("not listing owner");

  //   await marketplace.cancelList(id, 0);

  //   await expect(marketplace.connect(other).cancelList(id, 0)).to.be.revertedWith("listing not avaialble");
  // });

  it("Should not cancel the list when already sold", async function () {
    const id = ethers.utils.solidityKeccak256(["address", "address", "uint256"], [owner.address, mockERC1155.address, 1]);
    await marketplace.list(mockERC1155.address, 1, parseEther("1"), 3, mockERC20.address);

    mockERC20.transfer(other.address, parseEther("4"));
    mockERC20.connect(other).approve(marketplace.address, parseEther("4"));
    await marketplace.connect(other).buyWithToken(id, 0, 3);

    await expect(marketplace.connect(other).cancelList(id, 0)).to.be.revertedWith("listing not avaialble");
  });

  // Test wrapper logic in marketplace

  it("Should fail listing of non-wrapped non-std contract", async function () {
    await mockNonERC721.mint(1);
    await expect(marketplace.list(mockNonERC721.address, 1, parseEther("1"), 1, ethers.constants.AddressZero)).to.be.revertedWith("Unsupported Contract interface");
  });

  it("Should list of wrapped non-std contract", async function () {
    await wrapperRegistry.register(mockNonERC721.address,mockNonERC721Wrapper.address,'NonERC721')
    let a = await wrapperRegistry.isRegistered(mockNonERC721Wrapper.address)
    expect(a).to.be.true

    await mockNonERC721.setApprovalForAll(mockNonERC721Wrapper.address, true)

    const id1 = ethers.utils.solidityKeccak256(["address", "address", "uint256"], [owner.address, mockNonERC721.address, 1]);
    await expect(marketplace.list(mockNonERC721.address, 1, parseEther("1"), 1, ethers.constants.AddressZero)).to.not.be.reverted;
 
    const list = await marketplace.getListing(id1, 0);
    expect(list.seller).to.be.equal(owner.address);
    expect(list.contractAddress).to.be.equal(mockNonERC721.address);
    expect(list.price).to.be.equal(parseEther("1"));
    expect(list.quantity).to.be.equal(1);
  });

  it("Should buy non-std contract", async function () {
    const id1 = ethers.utils.solidityKeccak256(["address", "address", "uint256"], [owner.address, mockNonERC721.address, 1]);
    await mockNonERC721.setApprovalForAll(mockNonERC721Wrapper.address, true)
    await expect(marketplace.list(mockNonERC721.address, 1, parseEther("1"), 1, ethers.constants.AddressZero)).to.not.be.reverted;
 
    await expect(marketplace.connect(other).buy(id1, 0, 1, {value: parseEther("0.9")})).to.be.reverted;

    await expect(() => marketplace.connect(other).buy(id1, 0, 1, {value: parseEther("1")})).to.be.changeEtherBalance(owner, parseEther("1"));
    expect(await mockNonERC721.ownerOf(1)).to.be.equal(other.address);
  });

  it("Should list NFT several times", async function () {
    const id = ethers.utils.solidityKeccak256(["address", "address", "uint256"], [owner.address, mockERC1155.address, 1]);

    await marketplace.list(mockERC1155.address, 1, parseEther("1"), 1, mockERC20.address);
    await marketplace.list(mockERC1155.address, 1, parseEther("2"), 2, mockERC20.address);
    await marketplace.list(mockERC1155.address, 1, parseEther("3"), 1, mockERC20.address);

    const listingCount = await marketplace.getListingCount(id);
    expect(listingCount).to.be.equal(3);
    const listings = await marketplace.getListings(id);

    expect(listings[0].price).to.be.equal(parseEther("1"));
    expect(listings[0].quantity).to.be.equal(1);

    expect(listings[1].price).to.be.equal(parseEther("2"));
    expect(listings[1].quantity).to.be.equal(2);

    expect(listings[2].price).to.be.equal(parseEther("3"));
    expect(listings[2].quantity).to.be.equal(1);
   });

});

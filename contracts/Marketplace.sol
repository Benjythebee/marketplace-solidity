// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165CheckerUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@opengsn/contracts/src/BaseRelayRecipient.sol";
import "./lib/keyset.sol";
import "./IWrappersRegistry.sol";
import "./Wrappers/ICollectionWrapper.sol";

/* We may need to modify the ERCRegistery
  - whenToken :  if the token is no registered, it will return true;
  - We should have the function to check if the address is registered
  - I am wondering if we need to check the decimals. If the frontend manage this, we don't need it
  - how can we manage the price with different tokens or etherem
  - there should be cancelsale
*/
interface IERC20Registry {
    function register(
        address _addr,
        string memory _symbol,
        uint256 _decimals,
        string memory _name
    ) external payable returns (bool);

    function togglePause(bool _paused) external;

    function unregister(uint256 _id) external;

    function setFee(uint256 _fee) external;

    function drain() external;

    function token(uint256 _id)
        external
        view
        returns (
            address addr,
            string memory symbol,
            uint256 decimals,
            string memory name
        );

    function fromAddress(address _addr)
        external
        view
        returns (
            uint256 id,
            string memory symbol,
            uint256 decimals,
            string memory name
        );

    function fromSymbol(string memory _symbol)
        external
        view
        returns (
            uint256 id,
            address addr,
            uint256 decimals,
            string memory name
        );

    function registerAs(
        address _addr,
        string memory _symbol,
        uint256 _decimals,
        string memory _name
    ) external payable returns (bool);

    function isRegistered(address _addr) external returns (bool);
}

struct Listing {
    address seller;
    address contractAddress;
    uint256 tokenId;
    uint256 price;
    uint256 quantity;
    address acceptedPayment;
}

contract Marketplace is PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable, BaseRelayRecipient {
    event NewListing(    
        address indexed seller,
        address indexed contractAddress,
        uint tokenId,
        uint price,
        uint quantity,
        bytes32 listingId,
        uint listingIndex,
        address acceptedPayment,
        uint listedDate
    );

    event SaleWithToken(    
        address indexed seller,
        address indexed buyer,
        address contractAddress,
        uint tokenId,
        uint price,
        uint quantity,
        address accesptedPayment,
        bytes32 indexed listingId,
        uint listingIndex,
        uint saledDate       
    );
    event Sale(    
        address indexed seller,
        address indexed buyer,
        address contractAddress,
        uint tokenId,
        uint price,
        uint quantity,
        address accesptedPayment,
        bytes32 indexed listingId,
        uint listingIndex,
        uint saledDate
    );

    event CancelSale(
        bytes32 indexed listingId,
        uint listingIndex,
        uint cancelledDate
    );
    uint256 counter;
    using ERC165CheckerUpgradeable for address;
    using KeySetLib for KeySetLib.Set;

    mapping(bytes32 => Listing[]) listings;
    KeySetLib.Set set;

    IWrappersRegistry public wrapperRegistry;
    IERC20Registry internal registryAddress;
    uint256 public minPrice;
    uint256 public maxPrice;


    bytes4 public constant IID_IERC1155 = type(IERC1155Upgradeable).interfaceId;
    bytes4 public constant IID_IERC721 = type(IERC721Upgradeable).interfaceId;

    /**
     *@dev Initialize contract;
     *@param _registryAddress is the address of the ERC20 token registry.
     *@param _wrapperRegistry is the address of the registry for Wrappers
     *@param _forwarder is the address of the trusted forwarder.
     */
    function initialize (address _registryAddress,address _wrapperRegistry, address _forwarder) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init();
        __Pausable_init();

        registryAddress = IERC20Registry(_registryAddress);
        ///@dev Some wearables are incredibly cheap.
        minPrice = 0.001 ether;
        maxPrice = type(uint).max;
        _setTrustedForwarder(_forwarder);

        wrapperRegistry = IWrappersRegistry(_wrapperRegistry);
    }

    modifier onlyAvailableListing(bytes32 _listingId, uint256 _listingIndex) {
        require(listings[_listingId].length !=0
               && listings[_listingId][_listingIndex].quantity != 0,
               "listing not avaialble"
        );
        _;
    }

    modifier onlyNFT(address _address) {
        require(isERC1155(_address) || isERC721(_address) || isRegisteredContract(_address),"Unsupported Contract interface");
        _;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    function isERC721(address _address) public view returns (bool) {
        return _address.supportsInterface(IID_IERC721);
    }

    function isERC1155(address _address) public view returns (bool) {
        return _address.supportsInterface(IID_IERC1155);
    }

    function isRegisteredContract(address _address) public view returns (bool) {
        return wrapperRegistry.isWrapped(_address);
    }

    function getListingCount () public view returns (uint) {
        return set.count();
    }

    // function getListingIdAtIndex(uint256 index) public view returns (bytes32) {
    //     return set.keyAtIndex(index);
    // }

    function getListingsAtIndex(uint256 index)
        public
        view
        returns (Listing[] memory)
    {
        return listings[set.keyAtIndex(index)];
    }

    function getListing(bytes32 id, uint256 listingIndex) public view returns (Listing memory) {
        return listings[id][listingIndex];
    }

    // function getListings() public view returns (Listing[] memory) {
    //     uint256 len = getListingCount();
    //     Listing[] memory _listings = new Listing[](len);
    //     for (uint256 i = 0; i < len; i++) {
    //         _listings[i] = getListingAtIndex(i);
    //     }
    //     return _listings;
    // }

    function _generateId(
        address _seller,
        address _contractAddress,
        uint256 _tokenId
    ) private pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(_seller, _contractAddress, _tokenId)
            );
    }

    function isExistId(bytes32 id) public view returns (bool) {
        return set.exists(id);
    }

    function isListingValid(bytes32 id, uint256 listingIndex) public view returns (bool) {
        if (!isExistId(id)) {
            return false;
        }
        Listing memory listing = listings[id][listingIndex];
        return
            _hasNFTApproval(listing.contractAddress, listing.seller) &&
            _hasNFTOwnership(
                listing.contractAddress,
                listing.seller,
                listing.tokenId,
                listing.quantity
            );
    }

    function _hasNFTApproval(address _nftAddress, address _from)
        internal
        view
        returns (bool)
    {
        if (isERC1155(_nftAddress) || isERC721(_nftAddress)) {
            return IERC1155(_nftAddress).isApprovedForAll(_from, address(this));
        } else {
            (,,address _wrapper,)=wrapperRegistry.fromImplementationAddress(_nftAddress);
            //@dev Test if the wrapper is approved, not the marketplace.
            //@dev this isn't great as it might be confusing for the user.
            return ICollectionWrapper(_wrapper).isApprovedForAll(_from, _wrapper);
        }
    }

    function _hasNFTOwnership(
        address _nftAddress,
        address _from,
        uint256 _tokenId,
        uint256 _quantity
    ) private view returns (bool) {
        if (isERC1155(_nftAddress)) {
            return IERC1155(_nftAddress).balanceOf(_from, _tokenId) >= _quantity;
        } else if(isERC721(_nftAddress)) {
            return IERC721(_nftAddress).ownerOf(_tokenId) == _from;
        } else {
            (,,address _wrapper,)=wrapperRegistry.fromImplementationAddress(_nftAddress);
            return ICollectionWrapper(_wrapper).balanceOf(_from, _tokenId) >= _quantity;
        }
        
    }

    function _transferNFT(
        address _nftAddress,
        address _from,
        address _to,
        uint256 _tokenId,
        uint256 _quantity
    ) private returns (bool) {
        if (isERC1155(_nftAddress)) {
            IERC1155(_nftAddress).safeTransferFrom(
                _from,
                _to,
                _tokenId,
                _quantity,
                "0x0"
            );
        } else if(isERC721(_nftAddress)) {
            IERC721(_nftAddress).transferFrom(_from, _to, _tokenId);
        } else {
            (,,address _wrapper,)=wrapperRegistry.fromImplementationAddress(_nftAddress);
            ICollectionWrapper(_wrapper).transferFrom(_from, _to, _tokenId,_quantity);
        }
        return true;
    }

    function list(
        address nftAddress,
        uint256 tokenId,
        uint256 price,
        uint256 quantity,
        address acceptedPayment
    ) public onlyNFT(nftAddress) whenNotPaused returns (bytes32) {
        require(price >= minPrice, "Price less than minimum");
        require(price < maxPrice, "Price more than maximum");
        require(quantity > 0, "Quantity is 0");
        bool isRegistered = registryAddress.isRegistered(acceptedPayment);
        if (!isRegistered && acceptedPayment != address(0)) {
            revert("not registered token");
        }
        require(_hasNFTApproval(nftAddress,_msgSender()),"Contract is not approved");

        if (isERC1155(nftAddress)) {
            if (
                IERC1155(nftAddress).balanceOf(_msgSender(), tokenId) < quantity
            ) {
                revert("insufficient balance");
            }
        } else if(isERC721(nftAddress)) {
            if (IERC721(nftAddress).ownerOf(tokenId) == _msgSender()) {
                revert("not owner of token");
            }
            require(quantity == 1, "quantity should be 1");
        } else {
            (,,address _wrapper,)=wrapperRegistry.fromImplementationAddress(nftAddress);
            if (ICollectionWrapper(_wrapper).balanceOf(_msgSender(), tokenId) < quantity) {
                revert("not owner of token");
            }
        }

        bytes32 id = _generateId(_msgSender(), nftAddress, tokenId);

        // require(!isExistId(id), "Listing already exists");

        Listing memory l;

        l.seller = _msgSender();
        l.contractAddress = nftAddress;
        l.tokenId = tokenId;
        l.price = price;
        l.quantity = quantity;
        l.acceptedPayment = acceptedPayment;
        listings[id].push(l);

        set.insert(id);

        uint listingLength = listings[id].length;

        emit NewListing(
            _msgSender(),
            nftAddress,
            tokenId,
            price,
            quantity,
            id,
            listingLength - 1,
            acceptedPayment,
            block.timestamp
        );

        return id;
    }

    function buyWithToken(bytes32 id, uint256 listingIndex, uint256 quantity) 
        public whenNotPaused onlyAvailableListing(id, listingIndex) 
    {
        require(isExistId(id), "Id does not exist");
        require(isListingValid(id, listingIndex), "Listing is invalid");
        require(quantity > 0, "Quantity is 0");

        Listing memory l = listings[id][listingIndex];
        require(l.acceptedPayment != address(0), "should pay erc20 token");

        address nft = l.contractAddress;
        IERC20Upgradeable token = IERC20Upgradeable(l.acceptedPayment);

        require(l.quantity >= quantity, "Quantity unavailable");
        require(l.seller != _msgSender(), "Buyer cannot be seller");

        require(
            token.balanceOf(_msgSender()) >= l.price * quantity,
            "insufficient balance"
        );
        require(
            token.transferFrom(_msgSender(), l.seller, l.price * quantity),
            "Could not send ERC20 token"
        );

        require(
            _transferNFT(nft, l.seller, _msgSender(), l.tokenId, quantity),
            "Could not send NFT"
        );

        listings[id][listingIndex].quantity -= quantity;

        // if (l.quantity == 0) {
        //     set.remove(id);
        //     delete listings[id][listingIndex];
        // }

        emit SaleWithToken(
            l.seller,
            _msgSender(),
            l.contractAddress,
            l.tokenId,
            l.price,
            quantity,
            l.acceptedPayment,
            id,
            listingIndex,
            block.timestamp
        );
    }

    function buy(bytes32 id, uint256 listingIndex, uint256 quantity) 
        public payable whenNotPaused onlyAvailableListing (id, listingIndex) 
    {
        require(isExistId(id), "Id does not exist");
        require(isListingValid(id, listingIndex), "Listing is invalid");
        Listing memory l = listings[id][listingIndex];
        require(l.acceptedPayment == address(0), "should pay ether");
        address nft = l.contractAddress;

        require(l.quantity >= quantity, "Quantity unavailable");
        require(l.seller != _msgSender(), "Buyer cannot be seller");
        require(msg.value == l.price * quantity, "invalid amount");

        (bool success, ) = payable(l.seller).call{value: msg.value}("");
        require(success, "Failed to transfer native token");

        require(
            _transferNFT(nft, l.seller, _msgSender(), l.tokenId, quantity),
            "Could not transfer NFT"
        );

        listings[id][listingIndex].quantity -= quantity;

        // if (l.quantity == 0) {
        //     set.remove(id);
        //     delete listings[id];
        // }

        emit Sale(
            l.seller,
            _msgSender(),
            l.contractAddress,
            l.tokenId,
            l.price,
            quantity,
            l.acceptedPayment,
            id,
            listingIndex,
            block.timestamp
        );
    }

    function cancelList(bytes32 id, uint256 listingIndex) public onlyAvailableListing(id, listingIndex) {
        require(isExistId(id), "Id does not exist");
        Listing memory l = listings[id][listingIndex];
        require(l.seller == _msgSender(), "not listing owner");
        require(l.quantity > 0, "no quantity");

        // set.remove(id);
        delete listings[id][listingIndex];

        emit CancelSale(id, listingIndex, block.timestamp);
    }

    function setMin(uint256 t) public onlyOwner {
        require(t < maxPrice);
        minPrice = t;
    }

    function setMax(uint256 t) public onlyOwner {
        require(t > minPrice);
        maxPrice = t;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function supportsInterface(bytes4 interfaceId)
        external
        view
        virtual
        returns (bool)
    {
        return interfaceId == type(IERC165Upgradeable).interfaceId;
    }

    function _msgData()
        internal
        view
        virtual
        override(BaseRelayRecipient, ContextUpgradeable)
        returns (bytes calldata)
    {
        return super._msgData();
        // if (msg.data.length >= 20 && isTrustedForwarder(msg.sender)) {
        //     return msg.data[0:msg.data.length-20];
        // } else {
        //     return msg.data;
        // }
    }

    function _msgSender()
        internal
        view
        virtual
        override(BaseRelayRecipient, ContextUpgradeable)
        returns (address)
    {
        return super._msgSender();
    }

    function versionRecipient() public pure override returns (string memory) {
        return "2.2.1";
    }

    function updateTokenRegistry(address _newAddress) public onlyOwner {
        registryAddress = IERC20Registry(_newAddress);
    }
}

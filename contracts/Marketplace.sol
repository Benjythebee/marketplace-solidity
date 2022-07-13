// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165CheckerUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@opengsn/contracts/src/BaseRelayRecipient.sol";
import "./lib/keyset.sol";
import "./lib/IApprovalForAll.sol";
import "./IWrappersRegistry.sol";
import "./Wrappers/ICollectionWrapper.sol";
import "./IERC20Registry.sol";
/* We may need to modify the ERCRegistery
  - whenToken :  if the token is no registered, it will return true;
  - We should have the function to check if the address is registered
  - I am wondering if we need to check the decimals. If the frontend manage this, we don't need it
  - how can we manage the price with different tokens or etherem
  - there should be cancelsale
*/

struct Listing {
    address seller;
    address contractAddress;
    uint256 tokenId;
    uint256 price;
    uint256 quantity;
    address acceptedPayment;
}

struct Royalty {
    address royaltier;
    uint256 percent;
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
        bytes32 indexed listingId,
        uint listingIndex,
        uint quantity,
        uint saleDate
    );
    event Sale(    
        bytes32 indexed listingId,
        uint listingIndex,
        uint quantity,
        uint saleDate
    );

    event CancelSale(
        bytes32 indexed listingId,
        uint listingIndex,
        uint cancelledDate
    );

    using ERC165CheckerUpgradeable for address;
    using KeySetLib for KeySetLib.Set;
    
    ///@dev id => listings[], we can have many listings for the same token and owner (eg: ERC1155s)
    mapping(bytes32 => Listing[]) listings;
    ///@dev Create a set that will contain the hashes for listings
    KeySetLib.Set set;
    ///@dev A wrapper Registry address: A registry of contracts that wraps around non-standard NFT collections
    ///@dev See WrapperRegistry.sol
    IWrappersRegistry public wrapperRegistry;
    ///@dev A registry for ERC20 tokens, so users can pay with ERC20s
    IERC20Registry internal registryAddress;
    ///@dev the minimumPrice when listing an NFT
    uint256 public minPrice;
    ///@dev the maximum Price when listing an NFT
    uint256 public maxPrice;
    ///@dev fee for listing on this marketplace; Units = basis points;  1% = 100, 100% = 1000
    uint256 public fee;
    uint256 constant SCALE = 10000;
    ///@dev royalty lookup; NFT collection -> royalty
    mapping(address => Royalty) royalties;

    bytes4 public constant IID_IERC1155 = type(IERC1155Upgradeable).interfaceId;
    bytes4 public constant IID_IERC721 = type(IERC721Upgradeable).interfaceId;
    bytes4 public constant IID_IERC2981 = type(IERC2981).interfaceId;

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
        fee = 500;
        _setTrustedForwarder(_forwarder);

        wrapperRegistry = IWrappersRegistry(_wrapperRegistry);
    }

    /**
     *@dev Modifier to check if the listing is avaialble
     *@param _listingId is the hash of NFT, which is generated by tokenAddress, tokenId and token owner
     *@param _listingIndex is the index of listings
     */
    modifier onlyAvailableListing(bytes32 _listingId, uint256 _listingIndex) {
        require(listings[_listingId].length !=0
               && listings[_listingId][_listingIndex].quantity != 0,
               "listing not avaialble"
        );
        _;
    }
    ///@dev require the address is a supported NFT contract
    modifier onlyNFT(address _address) {
        require(isERC1155(_address) || isERC721(_address) || isRegisteredContract(_address),"Unsupported Contract interface");
        _;
    }
    ///@dev Virtual
    ///for proxy
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    function isERC721(address _address) internal view returns (bool) {
        return _address.supportsInterface(IID_IERC721);
    }

    function isERC1155(address _address) internal view returns (bool) {
        return _address.supportsInterface(IID_IERC1155);
    }
    ///@dev Checks the wrapper registry to see if address is a wrapped implementation
    function isRegisteredContract(address _address) internal view returns (bool) {
        return wrapperRegistry.isWrapped(_address);
    }

    function getListing(bytes32 id, uint256 listingIndex) public view returns (Listing memory) {
        require(listings[id].length > 0, "Listing of given id does not exist");
        return listings[id][listingIndex];
    }

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

    /**
     * @notice Check if the listing (given the id and listingIndex) exists and is valid.
     * @param id is the identifier of NFT
     * @param listingIndex is the index of listing
     */
    function isListingValid(bytes32 id, uint256 listingIndex) public view returns (bool) {
        if (!isExistId(id)) {
            return false;
        }
        Listing memory listing = getListing(id,listingIndex);
        return
            hasNFTApproval(listing.contractAddress, listing.seller) &&
            _hasNFTOwnership(
                listing.contractAddress,
                listing.seller,
                listing.tokenId,
                listing.quantity
            );
    }
    /**
     * @notice Check if collection has approved the marketplace to trade the user's item
     * @dev if the collection is not standard, we have to ask approval for the wrapper, not the marketplace.
     * We know the wrapper's implementation has to support `isApprovedForAll` (enforced when registered)
     * @param _nftAddress the collection's address
     * @param _from the address of the user that should give approval
     */
    function hasNFTApproval(address _nftAddress, address _from)
        public
        view
        returns (bool)
    {
        if (isERC1155(_nftAddress) || isERC721(_nftAddress)) {
            return IERC1155(_nftAddress).isApprovedForAll(_from, address(this));
        } else {
            (,,address _wrapper,)=wrapperRegistry.fromImplementationAddress(_nftAddress);
            //@dev Test if the wrapper is approved, not the marketplace.
            //@dev this isn't great as it might be confusing for the user.
            return IApprovalForAll(_nftAddress).isApprovedForAll(_from, _wrapper);
        }
    }
    /**
     * @notice Check if the user _from has ownership of _tokenId in collection _nftAddress (and quantity)
     * @dev if the collection is not standard, we use the wrapper. The wrapper will have instructions on how to obtain balance.
     * @param _nftAddress the collection's address
     * @param _from the address of the user that should give approval
     * @param _tokenId Token ID
     * @param _quantity the quantity; 1 for ERC721.
     */
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

    /**
     *@dev Transfer ERC1155, ERC721 and Wrapper contract
     *@param _nftAddress is the address of NFT
     *@param _from is the address of sender
     *@param _to is the address of receiver
     *@param _tokenId is the token ID
     *@param _quantity is the amount of NFT, if ERC721, it will be 1
     */
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

    /**
     *@dev List NFT to the marketplace
     *@param nftAddress is the address of NFT
     *@param tokenId is the tokenId of NFT
     *@param price is the listing price of NFT
     *@param quantity is the amount of NFT. If the NFT is ERC721, the quantity will be 1
     *@param acceptedPayment is the token address which can be used for sale
     *@return id (hash) and index (number)
     */
    function list(
        address nftAddress,
        uint256 tokenId,
        uint256 price,
        uint256 quantity,
        address acceptedPayment
    ) public onlyNFT(nftAddress) whenNotPaused returns (bytes32 id, uint index) {
        require(price >= minPrice, "Price less than minimum");
        require(price < maxPrice, "Price more than maximum");
        require(quantity > 0, "Quantity is 0");
        ///@dev check if tokenRegistryAddress has the acceptedPayment registered
        bool isRegistered = registryAddress.isRegistered(acceptedPayment);
        if (!isRegistered && acceptedPayment != address(0)) {
            revert("not registered token");
        }
        require(hasNFTApproval(nftAddress,_msgSender()),"Contract is not approved");

        ///@dev check ownership and quantity of the NFT compared to the listing parameters
        if (isERC1155(nftAddress)) {
            if (
                IERC1155(nftAddress).balanceOf(_msgSender(), tokenId) < quantity
            ) {
                revert("insufficient balance");
            }
        } else if(isERC721(nftAddress)) {
            if (IERC721(nftAddress).ownerOf(tokenId) != _msgSender()) {
                revert("not owner of token");
            }
            require(quantity == 1, "quantity should be 1");
        } else {
            (,,address _wrapper,)=wrapperRegistry.fromImplementationAddress(nftAddress);
            if (ICollectionWrapper(_wrapper).balanceOf(_msgSender(), tokenId) < quantity) {
                revert("not owner of token");
            }
        }

        ///@dev Generate an id for the given user+nftAddress and tokenID
        ///@dev this means a user can have multiple listings for the same NFT
        id = _generateId(_msgSender(), nftAddress, tokenId);

        Listing memory l;

        l.seller = _msgSender();
        l.contractAddress = nftAddress;
        l.tokenId = tokenId;
        l.price = price;
        l.quantity = quantity;
        l.acceptedPayment = acceptedPayment;

        if(listings[id].length>0 && listings[id][listings[id].length-1].quantity==0){
            ///@dev If we have a listing at index (listings[id].length-1) and it has no quantity, use index (listings[id].length-1).
            ///@dev While this is a very primitive and naive way of reusing space, we'll not very often have multiple listings of the same NFT by the same user.
            listings[id][listings[id].length-1] = l;
        }else{
            ///@dev we did not find a listing at 0 or the listing is valid, add the listing at index i+1
            listings[id].push(l);
        }

        ///@dev add id to the set of ids
        if (!set.exists(id)) {
            set.insert(id);
        }

        index = listings[id].length -1;

        emit NewListing(
            _msgSender(),
            nftAddress,
            tokenId,
            price,
            quantity,
            id,
            index,
            acceptedPayment,
            block.timestamp
        );
    }

    /**
     *@notice Buy the NFT with token, instead of native assets
     *@param id is the identifier for the NFT
     *@param listingIndex is the index of listing for the id
     *@param quantity is the amount of NFT that is going to buy
     */
    function buyWithToken(bytes32 id, uint256 listingIndex, uint256 quantity) 
        public whenNotPaused onlyAvailableListing(id, listingIndex) 
    {
        require(isListingValid(id, listingIndex), "Listing is invalid");
        require(quantity > 0, "Quantity cannot be 0");

        Listing memory l = getListing(id, listingIndex);
        require(l.acceptedPayment != address(0), "Listing can only be paid in non-native coin");

        address nft = l.contractAddress;
        IERC20Upgradeable token = IERC20Upgradeable(l.acceptedPayment);

        require(l.quantity >= quantity, "Quantity unavailable");
        require(l.seller != _msgSender(), "Buyer cannot be seller");

        uint256 salePrice = l.price * quantity;
        require(
            token.balanceOf(_msgSender()) >= salePrice,
            "insufficient balance"
        );
        
        ///@dev Transfer royalty to royaltier
        (address royaltier, uint256 royaltyAmount) = getRoyalty(nft, l.tokenId, salePrice);
        if (royaltyAmount > 0) {
            require(
                token.transferFrom(_msgSender(), royaltier, royaltyAmount),
                "Could not send ERC20 token for royalty"
            );
        }
        ///@dev Transfer marketplace fee to the marketplace
        uint256 feeAmount = salePrice * fee / SCALE;
        require(
            token.transferFrom(_msgSender(), address(this), feeAmount),
            "Could not send ERC20 token for fee"
        );
        
        ///@dev Transfer erc20 token to the seller
        uint256 amount = salePrice - feeAmount - royaltyAmount;
        require(
            token.transferFrom(_msgSender(), l.seller, amount),
            "Could not send ERC20 token"
        );

        require(
            _transferNFT(nft, l.seller, _msgSender(), l.tokenId, quantity),
            "Could not send NFT"
        );

        listings[id][listingIndex].quantity -= quantity;

        emit SaleWithToken(
            id,
            listingIndex,
            quantity,
            block.timestamp
        );
    }

    /**
     * @notice Buy the NFT using native assets
     * @param id is the identifier for the NFT
     * @param listingIndex is the index of listing for the id
     * @param quantity is the amount of NFT that is going to buy
     */
    function buy(bytes32 id, uint256 listingIndex, uint256 quantity) 
        public payable whenNotPaused onlyAvailableListing (id, listingIndex) 
    {
        require(isListingValid(id, listingIndex), "Listing is invalid");
        Listing memory l = getListing(id, listingIndex);
        require(l.acceptedPayment == address(0), "Listing wants ERC20, use buyWithToken");
        address nft = l.contractAddress;

        require(l.quantity >= quantity, "Quantity unavailable");
        require(l.seller != _msgSender(), "Buyer cannot be seller");
        require(msg.value == l.price * quantity, "Value does not match price*quantity");

        ///@dev Fee for listing on the marketplace
        uint256 feeAmount = msg.value * fee / SCALE;

        ///@dev Send RoyaltyAmount to royaltier
        (address royaltier, uint256 royaltyAmount) = getRoyalty(nft, l.tokenId, msg.value);
        bool success;
        if (royaltyAmount > 0) {
            (success, ) = payable(royaltier).call{value: royaltyAmount}("");
            require(success, "Failed to pay royalty");
        }

        ///@dev Send leftover profit from sale to seller
        uint256 amount = msg.value - feeAmount - royaltyAmount;
        (success, ) = payable(l.seller).call{value: amount}("");
        require(success, "Failed to transfer native token");

        require(
            _transferNFT(nft, l.seller, _msgSender(), l.tokenId, quantity),
            "Could not transfer NFT"
        );

        listings[id][listingIndex].quantity -= quantity;

        emit Sale(
            id,
            listingIndex,
            quantity,
            block.timestamp
        );
    }
    /**
     * @notice buyBatch of NFTs given the ids and indexes
     * @param ids list of hashes
     * @param listingIndexes list of indexes
     * @param quantities list of quantities
     */
    function buyBatch(bytes32[] memory ids, uint256[] memory listingIndexes,uint256[] memory quantities) public payable whenNotPaused {
        uint256 len = ids.length;
        require(len>0,"Ids length cannot be zero");
        require(len<=100,"Cannot buy more than 100 items at the same time");
        require(len == listingIndexes.length,"Size of IDs array and indexes does not match");
        require(len == quantities.length,"Size of quantity does not match ids");
        ///@dev hard limit to avoid DoS
        
        for(uint256 i = 0; i<len;i++){
            Listing memory l = getListing(ids[i], listingIndexes[i]);
            if(l.acceptedPayment != address(0)){
                buyWithToken(ids[i],listingIndexes[i],quantities[i]);
            }else{
                buy(ids[i],listingIndexes[i],quantities[i]);
            }
        }
    }
    /**
     * @notice Cancel the listing
     * @dev cancel a listing if it exists.
     * @param id is the identifier for the NFT
     * @param listingIndex is the index of listing for the id
     */
    function cancelList(bytes32 id, uint256 listingIndex) public onlyAvailableListing(id, listingIndex) {
        require(isExistId(id), "Id does not exist");
        Listing memory l = getListing(id, listingIndex);
        require(l.seller == _msgSender(), "not listing owner");
        require(l.quantity > 0, "no quantity");

        // set.remove(id);
        delete listings[id][listingIndex];

        emit CancelSale(id, listingIndex, block.timestamp);
    }
    /**
     * @notice cancel a batch of listings
     * @param ids list of hashes
     * @param listingIndexes list of indexes
     */
    function cancelBatch(bytes32[] memory ids, uint256[] memory listingIndexes) public {
        uint256 len = ids.length;
        require(len>0,"Ids length cannot be zero");
        require(len<100,"Cannot cancel more than 100 items at the same time");
        require(len == listingIndexes.length,"Size of IDs array and indexes does not match");
        ///@dev hard limit to avoid DoS
        
        for(uint256 i = 0; i<len;i++){
            cancelList(ids[i],listingIndexes[i]);
        }
    }
    /**
     *@notice Set the minimum listing price
     *@param t is the minium price
     */
    function setMin(uint256 t) public onlyOwner {
        require(t < maxPrice);
        minPrice = t;
    }

    /**
     *@notice Set the maximum listing price
     *@param t is the maximum price
     */
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

    ///@dev For paymaster x trustedForwarder
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
    ///@dev See standard EIP 2771
    function versionRecipient() public pure override returns (string memory) {
        return "2.2.1";
    }
    ///@dev Allows to change the address of the erc20 TokenRegistry.
    function updateTokenRegistry(address _newAddress) public onlyOwner {
        registryAddress = IERC20Registry(_newAddress);
    }
    ///@notice Set the marketplace's fee (in basis points)
    function setFee(uint256 _fee) public onlyOwner {
        fee = _fee;
    }
    /**
     * @notice Register royalty % in basis points (1% = 100)
     * @param _nftContract the collection to set the royalty fee for.
     * @param _royaltier The address that will receive the fee.
     * @param _percent % in basis points (1% = 100).
     */
    function registerRoyalty(address _nftContract, address _royaltier, uint256 _percent) external onlyOwner {
        royalties[_nftContract] = Royalty(_royaltier, _percent);
    }
    /**
     * @notice Remove royalties for a specific collection.
     * @param _nftContract the collection address
     */
    function removeRoyalty(address _nftContract) external onlyOwner {
        delete royalties[_nftContract];
    }

    function isRoyaltyStandard(address _contract) public view returns(bool) {
        return _contract.supportsInterface(IID_IERC2981);
    }
    /**
     * @notice Get the royalty % for a given NFT and price
     */
    function getRoyalty(address _contract, uint256 _tokenId, uint256 _price) internal view returns(address royaltier, uint256 royaltyAmount) {
        if (isRoyaltyStandard(_contract)) {
            (royaltier, royaltyAmount) = IERC2981(_contract).royaltyInfo(_tokenId, _price);
        } else if (royalties[_contract].royaltier != address(0)) {
            royaltyAmount = _price * royalties[_contract].percent / SCALE;
            royaltier = royalties[_contract].royaltier;
        }
    }
    ///@dev drain the balance of this contract.
    function withdraw() external onlyOwner {
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success, "Failed to withdraw");
    }
    ///@dev withdrawBalance of ERC20;
    function withdrawERC20(address _tokenAddress) external onlyOwner {
        IERC20Upgradeable token = IERC20Upgradeable(_tokenAddress);
        bool success = token.transfer( _msgSender(), token.balanceOf(address(this)));
        require(success, "Failed to withdraw");
    }
}

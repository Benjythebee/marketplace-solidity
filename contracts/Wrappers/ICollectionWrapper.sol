//SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
/**
 * INTERFACE of CollectionWrapper. Extend this for your wrapper.
 * The goal of this contract is to wrap an NFT smart contract that does not support ERC721 or ERC1155
 * This way the wrapper can tell us how to interact with a contract.
 */
interface ICollectionWrapper{

    /**
    * @dev This function should be public and should be overriden.
    * It should obtain an address and a tokenId as input and should return a uint256 value;
    * @dev This should be overriden with a set of instructions to obtain the balance of the user
    * When overriding this, if you do not need _tokenId, just ignore the input.
    * See ERC165 for help on interface support.
    * @param _user address of the user
    * @param _tokenId Token id of the NFT (if applicable)
    * @return bool
    * 
    */
    function balanceOf (address _user,uint _tokenId) external view  returns (uint256);

    /**
    * This function should be public and should be overriden.
    * It should obtain a uint256 token Id as input and should return an address (or address zero is no owner);
    * @dev This should be overriden and replaced with a set of instructions obtaining the owner of the given tokenId;
    *
    * @param _tokenId token id we want to grab the owner of.
    * @param _potentialOwner A potential owner, set address zero if no potentialOwner; This is necessary for ERC1155. Set zero address if none
    * @return address
    * 
    */
    function ownerOf(uint256 _tokenId,address _potentialOwner) external view  returns (address);

    /**
    * This function should be public and should be overriden.
    * It should obtain basic inputs to allow transfer of an NFT to another address.
    * @dev This should be overriden and replaced with a set of instructions telling your contract to transfer NFTs.
    *
    * @param _from Address of the owner
    * @param _to Address of the receiver
    * @param _tokenId token id we want to grab the owner of.
    * @param _quantity Quantity of the token to send; if your NFT doesn't have a quantity, just ignore.
    * @return address
    * 
    */
    function transferFrom(address _from, address _to,uint256 _tokenId,uint256 _quantity) external returns (bool);

}
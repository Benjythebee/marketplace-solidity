# CollectionWrappers

Sometimes smart contracts don't support ERC721 and ERC1155.
That's where the Wrapper comes in. A wrapper is a smart contract with a set of instructions telling us how to interact with your contract.
A Wrapper attempts at being a hybrid between ERC721 and ERC1155 to guarantee uni-compatibility

It has interface:
```js
interface ICollectionWrapper{
    function balanceOf (address _user,uint _tokenId) external view  returns (uint256);

    function ownerOf(uint256 _tokenId,address _potentialOwner) external view  returns (address);

    function transferFrom(address _from, address _to,uint256 _tokenId,uint256 _quantity) external view returns (bool);

    function isApprovedForAll(address _from,address _operator) external view  returns (bool);

    function supportsInterface(bytes4 interfaceId) external pure  returns (bool);
}
```

All the functions should be overriden with the appropriate set of instruction to interact with your contract.

**For example:**

Your contract has an interface similar to ERC721 but isn't recognised as one:
Simply wrap your contract's balanceOf, ownerOf,... 

Example:

```js
balanceOf(address _user,uint256 _tokenId)... override...{
    
    return MyContract(_implementation).balanceOf(_user);
}

ownerOf(uint256 _tokenId,address _potentialOwner)... override...{
    
    return MyContract(_implementation).ownerOf(_tokenId);
}

isApprovedForAll(address _user,address _operator)... override...{
    
    return MyContract(_implementation).isApprovedForAll(_user,_operator);
}
```

Then deploy the CollectionWrapper and set the _implementation = your contract address in the constructor.

Make sure the Interface is supported.

```js

    /**
     * See ERC165 -supportInterface()
     */
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(ICollectionWrapper).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
```

## Make my own.
A good place to start is to have a look at `DefaultWrapper.sol`, copy paste it and make the appropriate changes.

The wrapper should not be Ownable.

Deploy the Wrapper and verify it.

Then make an issue on the Github saying you would like it to be registered onto the CollectionWrapper register.
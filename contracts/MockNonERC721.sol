// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockNonERC721 is ERC721 {

    constructor () ERC721("Mock NFT", "MT"){
    }

    function mint(uint256 id) public {
        _mint(msg.sender, id);
    }

    /**
     * See ERC165 -supportInterface()
     * purposely say we dont support ERC721
     */
    function supportsInterface(bytes4 interfaceId) public pure override(ERC721) returns (bool) {
        return false;
    }
}
// SDPX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC1155 is ERC20 {

    constructor () ERC20("Mock Toekn", "MT"){
        _mint(msg.sender, 1000000 * 10 ** 18);
    }
}
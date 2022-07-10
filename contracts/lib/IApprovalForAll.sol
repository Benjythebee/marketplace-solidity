//SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/**
 * INTERFACE for ApprovalForAll
 */
interface IApprovalForAll{
        function isApprovedForAll(address _owner,address _operator) external view returns (bool);
        function setApprovalForAll(address operator,bool _approved) external;
}
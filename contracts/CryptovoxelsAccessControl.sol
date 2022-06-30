//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


// Contract already deployed

contract CryptovoxelsAccessControl is AccessControl, Ownable {

  /// @dev Create the admin role, with `_msgSender` as a first member.
  constructor () {
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
  }

  /// @dev Restricted to members of Cryptovoxels.
  modifier onlyMember() {
    require(isMember(_msgSender()), "Restricted to members.");
    _;
  }
  /// @dev Return `true` if the `account` belongs to Cryptovoxels.
  function isMember(address account)
    public view returns (bool)
  {
    return hasRole(DEFAULT_ADMIN_ROLE, account);
  }
  /// @dev Add a member of Cryptovoxels.
  function addMember(address account) external onlyMember {
    grantRole(DEFAULT_ADMIN_ROLE, account);
  }
  /// @dev Remove yourself from Cryptovoxels team.
  function leave() external {
    renounceRole(DEFAULT_ADMIN_ROLE, _msgSender());
  }

    /// @dev Remove yourself from Cryptovoxels team.
  function removeMember(address account) external onlyMember {
    revokeRole(DEFAULT_ADMIN_ROLE, account);
  }

    /// @dev Override revokeRole, owner Of Contract should always be an admin
    function revokeRole(bytes32 role, address account) public override onlyRole(getRoleAdmin(role)) {
        require(account != owner(),'Cant revoke role of owner of contract');
        super._revokeRole(role, account);
    }
}
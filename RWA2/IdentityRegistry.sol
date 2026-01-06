// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract IdentityRegistry is Ownable(msg.sender) {
    mapping(address => bool) private _hasIdentity;

    event IdentityRegistered(address indexed user);
    event IdentityRevoked(address indexed user);

    function registerIdentity(address user) external onlyOwner {
        require(user != address(0), "ZERO_ADDRESS");
        _hasIdentity[user] = true;
        emit IdentityRegistered(user);
    }

    function revokeIdentity(address user) external onlyOwner {
        _hasIdentity[user] = false;
        emit IdentityRevoked(user);
    }

    function hasIdentity(address user) external view returns (bool) {
        return _hasIdentity[user];
    }
}

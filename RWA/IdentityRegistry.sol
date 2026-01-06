// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract IdentityRegistry {
    address public owner;
    mapping(address => bool) private verified;

    event IdentityVerified(address indexed user);
    event IdentityRevoked(address indexed user);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function verify(address user) external onlyOwner {
        verified[user] = true;
        emit IdentityVerified(user);
    }

    function revoke(address user) external onlyOwner {
        verified[user] = false;
        emit IdentityRevoked(user);
    }

    function isVerified(address user) external view returns (bool) {
        return verified[user];
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IIdentityRegistry {
    function hasIdentity(address user) external view returns (bool);
}

contract RWAToken is ERC20, Ownable(msg.sender) {
    IIdentityRegistry public identityRegistry;
    uint256 public immutable assetId;

    error IdentityRequired(address user);

    constructor(
        string memory name_,
        string memory symbol_,
        address identityRegistry_,
        uint256 assetId_
    ) ERC20(name_, symbol_) {
        require(identityRegistry_ != address(0), "ZERO_IDENTITY_REGISTRY");
        identityRegistry = IIdentityRegistry(identityRegistry_);
        assetId = assetId_;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (from != address(0)) {
            if (!identityRegistry.hasIdentity(from)) {
                revert IdentityRequired(from);
            }
        }

        if (to != address(0)) {
            if (!identityRegistry.hasIdentity(to)) {
                revert IdentityRequired(to);
            }
        }

        super._beforeTokenTransfer(from, to, amount);
    }
}

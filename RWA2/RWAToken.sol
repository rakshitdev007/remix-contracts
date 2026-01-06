// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IIdentityRegistry {
    function hasIdentity(address user) external view returns (bool);
}

contract RWAToken is ERC20, Ownable(msg.sender) {
    IIdentityRegistry public immutable identityRegistry;
    uint256 public immutable assetId;

    uint256 private constant BPS_DENOMINATOR = 10_000;

    error IdentityRequired(address user);
    error InvalidDistribution();
    error ZeroAddress();

    constructor(
        string memory name_,
        string memory symbol_,
        address identityRegistry_,
        uint256 assetId_,
        address[] memory initialOwners,
        uint256[] memory percentagesBps,
        uint256 totalSupply_
    ) ERC20(name_, symbol_) {
        if (identityRegistry_ == address(0)) revert ZeroAddress();
        if (initialOwners.length != percentagesBps.length) revert InvalidDistribution();
        if (initialOwners.length == 0) revert InvalidDistribution();

        identityRegistry = IIdentityRegistry(identityRegistry_);
        assetId = assetId_;

        uint256 totalMinted;
        uint256 totalPercentage;

        for (uint256 i = 0; i < initialOwners.length; i++) {
            address owner = initialOwners[i];
            uint256 bps = percentagesBps[i];

            if (owner == address(0)) revert ZeroAddress();
            if (!identityRegistry.hasIdentity(owner)) {
                revert IdentityRequired(owner);
            }

            totalPercentage += bps;

            uint256 amount = (totalSupply_ * bps) / BPS_DENOMINATOR;
            totalMinted += amount;

            _mint(owner, amount);
        }

        // Ensure exactly 100% distribution
        if (totalPercentage != BPS_DENOMINATOR) revert InvalidDistribution();

        // Safety: ensure total supply matches
        if (totalMinted != totalSupply_) revert InvalidDistribution();
    }

    /**
     * @notice Optional controlled burn (redemption / buyback)
     */
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    /**
     * @dev ERC-3643-style compliance enforcement
     * OZ v5 requires overriding _update()
     */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override {
        // Skip identity check for mint
        if (from != address(0)) {
            if (!identityRegistry.hasIdentity(from)) {
                revert IdentityRequired(from);
            }
        }

        // Skip identity check for burn
        if (to != address(0)) {
            if (!identityRegistry.hasIdentity(to)) {
                revert IdentityRequired(to);
            }
        }

        super._update(from, to, value);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IIdentityRegistry {
    function isVerified(address user) external view returns (bool);
}

contract ComplianceModule {
    IIdentityRegistry public identityRegistry;

    constructor(address _identityRegistry) {
        identityRegistry = IIdentityRegistry(_identityRegistry);
    }

    function canTransfer(
        address from,
        address to,
        uint256 amount
    ) external view returns (bool) {
        if (amount == 0) return false;
        if (from == address(0) || to == address(0)) return false;

        return (
            identityRegistry.isVerified(from) &&
            identityRegistry.isVerified(to)
        );
    }
}

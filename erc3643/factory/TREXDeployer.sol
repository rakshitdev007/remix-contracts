// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "../token/TREXToken.sol";
import "../identity/IdentityRegistry.sol";
import "../storage/IdentityRegistryStorage.sol";
import "../registries/ClaimTopicsRegistry.sol";
import "../registries/TrustedIssuersRegistry.sol";
import "../compliance/ModularCompliance.sol";

/**
 * @title TREXDeployer
 * @dev Library for CREATE2 deployment of T-REX components
 */
library TREXDeployer {
    error DeploymentFailed();
    
    function deployIdentityRegistryStorage(bytes32 salt) internal returns (address) {
        bytes memory bytecode = type(IdentityRegistryStorage).creationCode;
        address deployed;
        assembly {
            deployed := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        if (deployed == address(0)) revert DeploymentFailed();
        return deployed;
    }
    
    function deployClaimTopicsRegistry(bytes32 salt) internal returns (address) {
        bytes memory bytecode = type(ClaimTopicsRegistry).creationCode;
        address deployed;
        assembly {
            deployed := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        if (deployed == address(0)) revert DeploymentFailed();
        return deployed;
    }
    
    function deployTrustedIssuersRegistry(bytes32 salt) internal returns (address) {
        bytes memory bytecode = type(TrustedIssuersRegistry).creationCode;
        address deployed;
        assembly {
            deployed := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        if (deployed == address(0)) revert DeploymentFailed();
        return deployed;
    }
    
    function deployIdentityRegistry(
        bytes32 salt,
        address trustedIssuersRegistry,
        address claimTopicsRegistry,
        address identityStorage
    ) internal returns (address) {
        bytes memory bytecode = abi.encodePacked(
            type(IdentityRegistry).creationCode,
            abi.encode(trustedIssuersRegistry, claimTopicsRegistry, identityStorage)
        );
        address deployed;
        assembly {
            deployed := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        if (deployed == address(0)) revert DeploymentFailed();
        return deployed;
    }
    
    function deployModularCompliance(bytes32 salt) internal returns (address) {
        bytes memory bytecode = type(ModularCompliance).creationCode;
        address deployed;
        assembly {
            deployed := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        if (deployed == address(0)) revert DeploymentFailed();
        return deployed;
    }
    
    function deployToken(
        bytes32 salt,
        string memory tokenName,
        string memory tokenSymbol,
        uint8 decimals,
        address identityRegistry,
        address compliance,
        address onchainId
    ) internal returns (address) {
        bytes memory bytecode = abi.encodePacked(
            type(TREXToken).creationCode,
            abi.encode(tokenName, tokenSymbol, decimals, identityRegistry, compliance, onchainId)
        );
        address deployed;
        assembly {
            deployed := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        if (deployed == address(0)) revert DeploymentFailed();
        return deployed;
    }
}

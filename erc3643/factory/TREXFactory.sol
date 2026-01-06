// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {TREXDeployer} from "./TREXDeployer.sol";
import {IOwnable} from "../interfaces/IOwnable.sol";

/**
 * @title TREXFactory
 * @dev Minimal factory using library for CREATE2 deployment
 */
contract TREXFactory {
    error InvalidSalt();
    
    function deployTREXSuite(
        bytes32 s,
        string calldata n,
        string calldata y,
        uint8 d,
        address o
    ) external returns (
        address t,
        address r,
        address c,
        address st,
        address ct,
        address ti
    ) {
        if (s == bytes32(0)) revert InvalidSalt();
        st = TREXDeployer.deployIdentityRegistryStorage(s);
        ct = TREXDeployer.deployClaimTopicsRegistry(s);
        ti = TREXDeployer.deployTrustedIssuersRegistry(s);
        r = TREXDeployer.deployIdentityRegistry(s, ti, ct, st);
        c = TREXDeployer.deployModularCompliance(s);
        t = TREXDeployer.deployToken(s, n, y, d, r, c, o);
        
        // Transfer compliance ownership to deployer
        IOwnable(c).transferOwnership(msg.sender);
    }
}

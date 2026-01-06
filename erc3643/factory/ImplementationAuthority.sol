// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ImplementationAuthority
 * @dev Manages upgradeable contract implementations
 */
contract ImplementationAuthority is Ownable {
    /// @dev Mapping of contract name hash to implementation address
    mapping(bytes32 => address) public implementations;
    
    /// @dev Mapping of contract name hash to version number
    mapping(bytes32 => uint256) public versions;
    
    /// @dev Events
    event ImplementationUpdated(bytes32 indexed name, address indexed implementation, uint256 version);
    
    /// @dev Custom errors
    error InvalidImplementation();
    error InvalidName();
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Sets implementation for a contract type
     * @param _name Contract name hash
     * @param _implementation Implementation address
     */
    function setImplementation(bytes32 _name, address _implementation) external onlyOwner {
        if (_name == bytes32(0)) revert InvalidName();
        if (_implementation == address(0)) revert InvalidImplementation();
        
        versions[_name]++;
        implementations[_name] = _implementation;
        
        emit ImplementationUpdated(_name, _implementation, versions[_name]);
    }
    
    /**
     * @dev Gets implementation for a contract type
     * @param _name Contract name hash
     * @return Implementation address
     */
    function getImplementation(bytes32 _name) external view returns (address) {
        return implementations[_name];
    }
    
    /**
     * @dev Gets version for a contract type
     * @param _name Contract name hash
     * @return Version number
     */
    function getVersion(bytes32 _name) external view returns (uint256) {
        return versions[_name];
    }
}

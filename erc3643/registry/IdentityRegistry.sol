// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "../interfaces/IIdentity.sol";
import "../storage/IdentityRegistryStorage.sol";
import "../registries/TrustedIssuersRegistry.sol";
import "../registries/ClaimTopicsRegistry.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title IdentityRegistry
 * @dev Central registry linking wallet addresses to ONCHAINID identities
 * @notice Manages identity registration and verification for token holders
 */
contract IdentityRegistry is Ownable { // https://testnet.bscscan.com/address/0x9337576034a6385c1798da46b6c9af9fcbbcb741#code
    /// @dev Storage contract for identity mappings
    IdentityRegistryStorage public identityStorage;
    
    /// @dev Registry of trusted claim issuers
    TrustedIssuersRegistry public issuersRegistry;
    
    /// @dev Registry of required claim topics
    ClaimTopicsRegistry public topicsRegistry;
    
    /// @dev Mapping of authorized agents
    mapping(address => bool) private agents;
    
    /// @dev Custom errors for gas efficiency
    error ZeroAddress();
    error NotAuthorized();
    error AlreadyRegistered();
    error NotRegistered();
    error AgentAlreadyExists();
    error AgentDoesNotExist();
    error ArrayLengthMismatch();
    
    /// @dev Events
    event ClaimTopicsRegistrySet(address indexed claimTopicsRegistry);
    event IdentityStorageSet(address indexed identityStorage);
    event TrustedIssuersRegistrySet(address indexed trustedIssuersRegistry);
    event IdentityRegistered(address indexed investorAddress, IIdentity indexed identity);
    event IdentityRemoved(address indexed investorAddress, IIdentity indexed identity);
    event IdentityUpdated(IIdentity indexed oldIdentity, IIdentity indexed newIdentity);
    event CountryUpdated(address indexed investorAddress, uint16 indexed country);
    event IdentityRecovered(address indexed oldWallet, address indexed newWallet, IIdentity indexed identity);
    event AgentAdded(address indexed agent);
    event AgentRemoved(address indexed agent);
    
    /**
     * @dev Modifier to check if caller is owner or agent
     */
    modifier onlyOwnerOrAgent() {
        if (msg.sender != owner() && !agents[msg.sender]) {
            revert NotAuthorized();
        }
        _;
    }
    
    /**
     * @dev Constructor
     * @param _trustedIssuersRegistry Address of TrustedIssuersRegistry
     * @param _claimTopicsRegistry Address of ClaimTopicsRegistry
     * @param _identityStorage Address of IdentityRegistryStorage
     */
    constructor(
        address _trustedIssuersRegistry,
        address _claimTopicsRegistry,
        address _identityStorage
    ) Ownable(msg.sender) {
        if (_trustedIssuersRegistry == address(0) || 
            _claimTopicsRegistry == address(0) || 
            _identityStorage == address(0)) {
            revert ZeroAddress();
        }
        
        issuersRegistry = TrustedIssuersRegistry(_trustedIssuersRegistry);
        topicsRegistry = ClaimTopicsRegistry(_claimTopicsRegistry);
        identityStorage = IdentityRegistryStorage(_identityStorage);
    }
    
    // ========== Registry Management Functions ==========
    
    /**
     * @dev Set the Identity Registry Storage contract
     * @param _identityStorage Address of new storage contract
     */
    function setIdentityRegistryStorage(address _identityStorage) external onlyOwner {
        if (_identityStorage == address(0)) revert ZeroAddress();
        
        identityStorage = IdentityRegistryStorage(_identityStorage);
        
        emit IdentityStorageSet(_identityStorage);
    }
    
    /**
     * @dev Set the Claim Topics Registry contract
     * @param _claimTopicsRegistry Address of new registry
     */
    function setClaimTopicsRegistry(address _claimTopicsRegistry) external onlyOwner {
        if (_claimTopicsRegistry == address(0)) revert ZeroAddress();
        
        topicsRegistry = ClaimTopicsRegistry(_claimTopicsRegistry);
        
        emit ClaimTopicsRegistrySet(_claimTopicsRegistry);
    }
    
    /**
     * @dev Set the Trusted Issuers Registry contract
     * @param _trustedIssuersRegistry Address of new registry
     */
    function setTrustedIssuersRegistry(address _trustedIssuersRegistry) external onlyOwner {
        if (_trustedIssuersRegistry == address(0)) revert ZeroAddress();
        
        issuersRegistry = TrustedIssuersRegistry(_trustedIssuersRegistry);
        
        emit TrustedIssuersRegistrySet(_trustedIssuersRegistry);
    }
    
    // ========== Agent Management Functions ==========
    
    /**
     * @dev Add an agent
     * @param _agent Address to add as agent
     */
    function addAgent(address _agent) external onlyOwner {
        if (_agent == address(0)) revert ZeroAddress();
        if (agents[_agent]) revert AgentAlreadyExists();
        
        agents[_agent] = true;
        
        emit AgentAdded(_agent);
    }
    
    /**
     * @dev Remove an agent
     * @param _agent Address to remove from agents
     */
    function removeAgent(address _agent) external onlyOwner {
        if (!agents[_agent]) revert AgentDoesNotExist();
        
        agents[_agent] = false;
        
        emit AgentRemoved(_agent);
    }
    
    /**
     * @dev Check if address is an agent
     * @param _address Address to check
     * @return True if address is an agent
     */
    function isAgent(address _address) external view returns (bool) {
        return agents[_address];
    }
    
    // ========== Identity Registration Functions ==========
    
    /**
     * @dev Register an identity
     * @param _userAddress Wallet address
     * @param _identity ONCHAINID identity contract
     * @param _country Country code (ISO-3166)
     */
    function registerIdentity(
        address _userAddress,
        IIdentity _identity,
        uint16 _country
    ) external onlyOwnerOrAgent {
        if (_userAddress == address(0)) revert ZeroAddress();
        if (address(identityStorage.storedIdentity(_userAddress)) != address(0)) {
            revert AlreadyRegistered();
        }
        
        identityStorage.addIdentityToStorage(_userAddress, _identity, _country);
        
        emit IdentityRegistered(_userAddress, _identity);
    }
    
    /**
     * @dev Batch register identities
     * @param _userAddresses Array of wallet addresses
     * @param _identities Array of identity contracts
     * @param _countries Array of country codes
     */
    function batchRegisterIdentity(
        address[] calldata _userAddresses,
        IIdentity[] calldata _identities,
        uint16[] calldata _countries
    ) external onlyOwnerOrAgent {
        if (_userAddresses.length != _identities.length || 
            _userAddresses.length != _countries.length) {
            revert ArrayLengthMismatch();
        }
        
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            if (_userAddresses[i] == address(0)) revert ZeroAddress();
            if (address(identityStorage.storedIdentity(_userAddresses[i])) != address(0)) {
                revert AlreadyRegistered();
            }
            
            identityStorage.addIdentityToStorage(
                _userAddresses[i],
                _identities[i],
                _countries[i]
            );
            
            emit IdentityRegistered(_userAddresses[i], _identities[i]);
        }
    }
    
    /**
     * @dev Delete an identity
     * @param _userAddress Wallet address
     */
    function deleteIdentity(address _userAddress) external onlyOwnerOrAgent {
        IIdentity userIdentity = identityStorage.storedIdentity(_userAddress);
        
        if (address(userIdentity) == address(0)) {
            revert NotRegistered();
        }
        
        identityStorage.removeIdentityFromStorage(_userAddress);
        
        emit IdentityRemoved(_userAddress, userIdentity);
    }
    
    /**
     * @dev Update an identity
     * @param _userAddress Wallet address
     * @param _identity New identity contract
     */
    function updateIdentity(address _userAddress, IIdentity _identity) 
        external 
        onlyOwnerOrAgent 
    {
        if (address(_identity) == address(0)) revert ZeroAddress();
        
        IIdentity oldIdentity = identityStorage.storedIdentity(_userAddress);
        
        if (address(oldIdentity) == address(0)) {
            revert NotRegistered();
        }
        
        identityStorage.modifyStoredIdentity(_userAddress, _identity);
        
        emit IdentityUpdated(oldIdentity, _identity);
    }
    
    /**
     * @dev Update a country
     * @param _userAddress Wallet address
     * @param _country New country code
     */
    function updateCountry(address _userAddress, uint16 _country) 
        external 
        onlyOwnerOrAgent 
    {
        if (address(identityStorage.storedIdentity(_userAddress)) == address(0)) {
            revert NotRegistered();
        }
        
        identityStorage.modifyStoredInvestorCountry(_userAddress, _country);
        
        emit CountryUpdated(_userAddress, _country);
    }
    
    /**
     * @dev Batch update countries
     * @param _userAddresses Array of wallet addresses
     * @param _countries Array of country codes
     */
    function batchUpdateCountry(
        address[] calldata _userAddresses,
        uint16[] calldata _countries
    ) external onlyOwnerOrAgent {
        if (_userAddresses.length != _countries.length) {
            revert ArrayLengthMismatch();
        }
        
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            if (address(identityStorage.storedIdentity(_userAddresses[i])) == address(0)) {
                revert NotRegistered();
            }
            
            identityStorage.modifyStoredInvestorCountry(_userAddresses[i], _countries[i]);
            
            emit CountryUpdated(_userAddresses[i], _countries[i]);
        }
    }
    
    /**
     * @dev Recover identity to a new wallet
     * @param _oldWallet The lost/compromised wallet address
     * @param _newWallet The new wallet address to recover to
     */
    function recoverIdentity(address _oldWallet, address _newWallet) 
        external 
        onlyOwnerOrAgent 
    {
        if (_newWallet == address(0)) revert ZeroAddress();
        if (_oldWallet == _newWallet) revert AlreadyRegistered();
        
        IIdentity userIdentity = identityStorage.storedIdentity(_oldWallet);
        if (address(userIdentity) == address(0)) revert NotRegistered();
        
        if (address(identityStorage.storedIdentity(_newWallet)) != address(0)) {
            revert AlreadyRegistered();
        }
        
        uint16 country = identityStorage.storedInvestorCountry(_oldWallet);
        
        // Remove from old wallet
        identityStorage.removeIdentityFromStorage(_oldWallet);
        
        // Add to new wallet
        identityStorage.addIdentityToStorage(_newWallet, userIdentity, country);
        
        emit IdentityRecovered(_oldWallet, _newWallet, userIdentity);
    }
    
    // ========== Query Functions ==========
    
    /**
     * @dev Check if address is registered
     * @param _userAddress Wallet address
     * @return True if registered
     */
    function contains(address _userAddress) external view returns (bool) {
        return address(identityStorage.storedIdentity(_userAddress)) != address(0);
    }
    
    /**
     * @dev Get identity for address
     * @param _userAddress Wallet address
     * @return The identity contract
     */
    function identity(address _userAddress) external view returns (IIdentity) {
        return identityStorage.storedIdentity(_userAddress);
    }
    
    /**
     * @dev Get country for address
     * @param _userAddress Wallet address
     * @return The country code
     */
    function investorCountry(address _userAddress) external view returns (uint16) {
        return identityStorage.storedInvestorCountry(_userAddress);
    }
    
    /**
     * @dev Verify if address is compliant (has valid claims)
     * @param _userAddress Wallet address
     * @return True if verified
     */
    function isVerified(address _userAddress) external view returns (bool) {
        IIdentity userIdentity = identityStorage.storedIdentity(_userAddress);
        
        if (address(userIdentity) == address(0)) {
            return false;
        }
        
        uint256[] memory requiredTopics = topicsRegistry.getClaimTopics();
        
        if (requiredTopics.length == 0) {
            return true;
        }
        
        for (uint256 i = 0; i < requiredTopics.length; i++) {
            bytes32[] memory claimIds = userIdentity.getClaimIdsByTopic(requiredTopics[i]);
            
            if (claimIds.length == 0) {
                return false;
            }
            
            bool hasValidClaim = false;
            
            for (uint256 j = 0; j < claimIds.length; j++) {
                (,, address issuer,,,) = userIdentity.getClaim(claimIds[j]);
                
                if (issuersRegistry.isTrustedIssuer(issuer) && 
                    issuersRegistry.hasClaimTopic(issuer, requiredTopics[i])) {
                    hasValidClaim = true;
                    break;
                }
            }
            
            if (!hasValidClaim) {
                return false;
            }
        }
        
        return true;
    }
}

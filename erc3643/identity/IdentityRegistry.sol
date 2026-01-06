// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IIdentityRegistry.sol";
import "../storage/IdentityRegistryStorage.sol";
import "../registries/ClaimTopicsRegistry.sol";
import "../registries/TrustedIssuersRegistry.sol";
import "../interfaces/IClaimTopicsRegistry.sol";
import "../interfaces/ITrustedIssuersRegistry.sol";

/**
 * @title IdentityRegistry
 * @dev Main registry managing investor identities and verification
 */
contract IdentityRegistry is IIdentityRegistry, Ownable {
    IIdentityRegistryStorage public override identityStorage;
    IClaimTopicsRegistry public override topicsRegistry;
    ITrustedIssuersRegistry public override issuersRegistry;
    
    /// @dev Events inherited from IIdentityRegistry interface
    
    constructor(
        address _trustedIssuersRegistry,
        address _claimTopicsRegistry,
        address _identityStorage
    ) Ownable(msg.sender) {
        require(_trustedIssuersRegistry != address(0), "Invalid issuers registry");
        require(_claimTopicsRegistry != address(0), "Invalid topics registry");
        require(_identityStorage != address(0), "Invalid identity storage");
        
        topicsRegistry = IClaimTopicsRegistry(_claimTopicsRegistry);
        issuersRegistry = ITrustedIssuersRegistry(_trustedIssuersRegistry);
        identityStorage = IIdentityRegistryStorage(_identityStorage);
        
    }
    
    /**
     * @notice Register an identity
     * @param userAddress Investor wallet address
     * @param _identity OnchainID contract
     * @param country Investor country code
     */
    function registerIdentity(
        address userAddress,
        IIdentity _identity,
        uint16 country
    ) external override onlyOwner {
        identityStorage.addIdentityToStorage(userAddress, _identity, country);
        emit IdentityRegistered(userAddress, _identity);
    }
    
    /**
     * @notice Update an identity
     * @param userAddress Investor wallet address
     * @param _identity New identity contract
     */
    function updateIdentity(address userAddress, IIdentity _identity) external override onlyOwner {
        IIdentity oldId = identityStorage.storedIdentity(userAddress);
        identityStorage.modifyStoredIdentity(userAddress, _identity);
        emit IdentityUpdated(oldId, _identity);
    }
    
    /**
     * @notice Update country for an investor
     * @param userAddress Investor wallet address
     * @param country New country code
     */
    function updateCountry(address userAddress, uint16 country) external override onlyOwner {
        identityStorage.modifyStoredInvestorCountry(userAddress, country);
        emit CountryUpdated(userAddress, country);
    }
    
    /**
     * @notice Delete an identity
     * @param userAddress Investor wallet address
     */
    function deleteIdentity(address userAddress) external override onlyOwner {
        IIdentity identityAddr = identityStorage.storedIdentity(userAddress);
        identityStorage.removeIdentityFromStorage(userAddress);
        emit IdentityRemoved(userAddress, identityAddr);
    }
    
    /**
     * @notice Set identity storage contract
     * @param _identityStorage Address of storage contract
     */
    function setIdentityRegistryStorage(address _identityStorage) external override onlyOwner {
        identityStorage = IIdentityRegistryStorage(_identityStorage);
        emit IdentityStorageSet(_identityStorage);
    }
    
    /**
     * @notice Set claim topics registry
     * @param _claimTopicsRegistry Address of registry
     */
    function setClaimTopicsRegistry(address _claimTopicsRegistry) external override onlyOwner {
        topicsRegistry = IClaimTopicsRegistry(_claimTopicsRegistry);
        emit ClaimTopicsRegistrySet(_claimTopicsRegistry);
    }
    
    /**
     * @notice Set trusted issuers registry
     * @param _trustedIssuersRegistry Address of registry
     */
    function setTrustedIssuersRegistry(address _trustedIssuersRegistry) external override onlyOwner {
        issuersRegistry = ITrustedIssuersRegistry(_trustedIssuersRegistry);
        emit TrustedIssuersRegistrySet(_trustedIssuersRegistry);
    }
    
    /**
     * @notice Check if an investor is verified
     * @param userAddress Investor address
     * @return True if verified
     */
    function isVerified(address userAddress) external view override returns (bool) {
        if (address(identityStorage.storedIdentity(userAddress)) == address(0)) {
            return false;
        }
        
        IIdentity identityContract = identityStorage.storedIdentity(userAddress);
        uint256[] memory requiredTopics = topicsRegistry.getClaimTopics();
        
        if (requiredTopics.length == 0) {
            return true;
        }
        
        for (uint256 i = 0; i < requiredTopics.length; i++) {
            bytes32[] memory claimIds = identityContract.getClaimIdsByTopic(requiredTopics[i]);
            
            if (claimIds.length == 0) {
                return false;
            }
            
            bool hasValidClaim = false;
            for (uint256 j = 0; j < claimIds.length; j++) {
                (uint256 topic, , address issuer, , , ) = identityContract.getClaim(claimIds[j]);
                
                if (topic == requiredTopics[i] && 
                    issuersRegistry.isTrustedIssuer(issuer) &&
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
    
    /**
     * @notice Get identity for an investor
     * @param userAddress Investor address
     * @return Identity contract address
     */
    function identity(address userAddress) external view override returns (IIdentity) {
        return identityStorage.storedIdentity(userAddress);
    }
    
    /**
     * @notice Get investor country
     * @param userAddress Investor address
     * @return Country code
     */
    function investorCountry(address userAddress) external view override returns (uint16) {
        return identityStorage.storedInvestorCountry(userAddress);
    }
    
    /**
     * @notice Check if address contains an identity
     * @param userAddress Address to check
     * @return True if identity exists
     */
    function contains(address userAddress) external view override returns (bool) {
        return address(identityStorage.storedIdentity(userAddress)) != address(0);
    }
    
    /**
     * @notice Batch register identities
     * @param userAddresses Array of investor addresses
     * @param identities Array of identity contracts
     * @param countries Array of country codes
     */
    function batchRegisterIdentity(
        address[] calldata userAddresses,
        IIdentity[] calldata identities,
        uint16[] calldata countries
    ) external override onlyOwner {
        require(
            userAddresses.length == identities.length && 
            userAddresses.length == countries.length,
            "Length mismatch"
        );
        
        for (uint256 i = 0; i < userAddresses.length; i++) {
            identityStorage.addIdentityToStorage(userAddresses[i], identities[i], countries[i]);
            emit IdentityRegistered(userAddresses[i], identities[i]);
        }
    }
    
    function isAgent(address _agent) external view override returns (bool) {
        return _agents[_agent];
    }
    
    function addAgent(address _agent) external override onlyOwner {
        require(_agent != address(0), "Invalid agent address");
        require(!_agents[_agent], "Agent already exists");
        _agents[_agent] = true;
        emit AgentAdded(_agent);
    }
    
    function removeAgent(address _agent) external override onlyOwner {
        require(_agents[_agent], "Agent does not exist");
        _agents[_agent] = false;
        emit AgentRemoved(_agent);
    }
    
    mapping(address => bool) private _agents;
}

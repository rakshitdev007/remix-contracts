// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title IdentityRegistry
 * @author Rakshit Kumar Singh
 * @dev Manages on-chain identity verification for users.
 *
 *      - Only the contract owner can register, update, or revoke identities.
 *      - Used by RWA tokens and other contracts to enforce identity checks.
 */
contract IdentityRegistry is Ownable {
    
    /**
     * @dev Represents a verified identity.
     * @param exists Whether the identity exists
     * @param identityURI Link to off-chain identity document (e.g., IPFS, URL)
     */
    struct Identity {
        bool exists;
        string identityURI;
        string countryCode;
    }

    /// @dev Mapping from user address to their Identity data
    mapping(address => Identity) private _identities;

    /// @dev Emitted when a new identity is registered
    event IdentityRegistered(address indexed user, string identityURI);

    /// @dev Emitted when an identity's URI is updated
    event IdentityUpdated(address indexed user, string newIdentityURI);

    /// @dev Emitted when an identity is revoked
    event IdentityRevoked(address indexed user);

    /// @dev Errors
    error ZeroAddress();
    error IdentityAlreadyExists();
    error IdentityDoesNotExist();

    /**
     * @notice Sets the initial contract owner
     * @param _initialOwner Owner of the registry
     */
    constructor(address _initialOwner) Ownable(_initialOwner) {}

    /**
     * @notice Registers a new identity for a user.
     * @dev Only the contract owner can call this.
     *      Cannot register a zero address or an already existing identity.
     * @param user Address of the user to register
     * @param identityURI Link to identity document
     */
    function registerIdentity(
        address user,
        string calldata identityURI,
        string calldata countryCode
    ) external onlyOwner {
        if (user == address(0)) revert ZeroAddress();
        if (_identities[user].exists) revert IdentityAlreadyExists();

        _identities[user] = Identity({
            exists: true,
            identityURI: identityURI,
            countryCode:countryCode
        });

        emit IdentityRegistered(user, identityURI);
    }

    /**
     * @notice Updates the identity document URI for an existing user.
     * @dev Only the contract owner can call this.
     *      User must already have a registered identity.
     * @param user Address of the user
     * @param newIdentityURI Updated URI for identity document
     */
    function updateIdentityURI(
        address user,
        string calldata newIdentityURI,
        string calldata newCountryCode
    ) external onlyOwner {
        if (!_identities[user].exists) revert IdentityDoesNotExist();

        _identities[user].identityURI = newIdentityURI;
        _identities[user].countryCode = newCountryCode;

        emit IdentityUpdated(user, newIdentityURI);
    }

    /**
     * @notice Revokes a user's identity.
     * @dev Only the contract owner can call this.
     *      Deletes the identity mapping.
     * @param user Address of the user
     */
    function revokeIdentity(address user) external onlyOwner {
        if (!_identities[user].exists) revert IdentityDoesNotExist();

        delete _identities[user];

        emit IdentityRevoked(user);
    }

    /**
     * @notice Checks if a user has a registered identity.
     * @param user Address of the user
     * @return True if the user is registered, false otherwise
     */
    function hasIdentity(address user) external view returns (bool) {
        return _identities[user].exists;
    }

    /**
     * @notice Returns full identity information for a user.
     * @param user Address of the user
     * @return exists True if the identity exists
     * @return identityURI URI of the identity document
     */
    function getIdentity(
        address user
    ) external view returns (bool exists, string memory identityURI) {
        Identity storage identity = _identities[user];
        return (identity.exists, identity.identityURI);
    }
}

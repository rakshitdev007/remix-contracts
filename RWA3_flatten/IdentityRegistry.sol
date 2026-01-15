// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// File: RWA3_flatten/IdentityRegistry.sol

/**
 * @title IdentityRegistry
 * @author Rakshit Kumar Singh
 * @dev Manages on-chain identity verification for users.
 *
 *      - Only the contract owner can register, update, or revoke identities.
 *      - Used by RWA tokens and manager contracts to enforce identity checks.
 */
contract IdentityRegistry is Ownable {
    /*===============================ENUMS===============================*/

    enum KYCLEVEL {
        none,
        basic,
        enhanced
    }

    /**
     * @dev Risk classification assigned off-chain by the administrator.
     *      This enum is informational and not enforced by on-chain logic.
     */
    enum RISKSCOREBAND {
        low,
        medium,
        high
    }

    /**
     * @dev Investor classification assigned off-chain by the administrator.
     *      This enum is informational and not enforced by on-chain logic.
     */
    enum INVESTORCLASS {
        retail,
        professional,
        accredited
    }

    /*===============================STRUCTS===============================*/

    /**
     * @dev Represents a verified on-chain identity.
     */
    struct Identity {
        uint256 verifiedTill;      // Expiry timestamp
        string identityURI;        // Off-chain KYC reference
        string countryCode;        // ISO / jurisdiction code (e.g., IN, US, +91)
        KYCLEVEL level;            // KYC level
        RISKSCOREBAND risk;        // Risk band
        INVESTORCLASS class;       // Investor class
    }

    /*===============================STORAGE===============================*/

    mapping(address => Identity) private _identities;

    /*===============================EVENTS===============================*/

    event IdentityRegistered(
        address indexed user,
        uint256 verifiedTill,
        string countryCode,
        string identityURI,
        KYCLEVEL level,
        RISKSCOREBAND risk,
        INVESTORCLASS class
    );

    event IdentityUpdated(address indexed user);
    event IdentityRevoked(address indexed user);

    /*===============================ERRORS===============================*/

    error ZeroAddress();
    error IdentityAlreadyVerified();
    error IdentityDoesNotExist();
    error IdentityInvalid(address user);

    /*===============================CONSTRUCTOR===============================*/

    constructor(address initialOwner) Ownable(initialOwner) {}

    /*===============================VIEWS===============================*/

    /**
     * @notice Returns true if the identity exists and is not expired.
     */
    function hasValidIdentity(address user) public view returns (bool) {
        Identity storage identity = _identities[user];
        return identity.verifiedTill != 0 && identity.verifiedTill >= block.timestamp;
    }

    /**
     * @dev Modifier to restrict access to verified identities.
     */
    modifier onlyVerified() {
        if (!hasValidIdentity(msg.sender)) {
            revert IdentityInvalid(msg.sender);
        }
        _;
    }

    /*===============================ADMIN FUNCTIONS===============================*/

    /**
     * @notice Registers a new identity.
     * @dev Only callable by the contract owner.
     */
    function registerIdentity(
        address user,
        uint256 verifiedTill,
        string calldata identityURI,
        string calldata countryCode,
        KYCLEVEL level,
        RISKSCOREBAND risk,
        INVESTORCLASS class
    ) external onlyOwner {
        if (user == address(0)) revert ZeroAddress();
        if (_identities[user].verifiedTill != 0)
            revert IdentityAlreadyVerified();

        _identities[user] = Identity({
            verifiedTill: verifiedTill,
            identityURI: identityURI,
            countryCode: countryCode,
            level: level,
            risk: risk,
            class: class
        });

        emit IdentityRegistered(
            user,
            verifiedTill,
            countryCode,
            identityURI,
            level,
            risk,
            class
        );
    }

    /**
     * @notice Updates an existing identity.
     * @dev Only callable by the contract owner.
     */
    function updateIdentity(
        address user,
        uint256 newVerifiedTill,
        string calldata newIdentityURI,
        string calldata newCountryCode,
        KYCLEVEL newLevel,
        RISKSCOREBAND newRisk,
        INVESTORCLASS newClass
    ) external onlyOwner {
        if (_identities[user].verifiedTill == 0)
            revert IdentityDoesNotExist();

        Identity storage identity = _identities[user];

        identity.verifiedTill = newVerifiedTill;
        identity.identityURI = newIdentityURI;
        identity.countryCode = newCountryCode;
        identity.level = newLevel;
        identity.risk = newRisk;
        identity.class = newClass;

        emit IdentityUpdated(user);
    }

    /**
     * @notice Revokes an identity permanently.
     * @dev Only callable by the contract owner.
     */
    function revokeIdentity(address user) external onlyOwner {
        if (_identities[user].verifiedTill == 0)
            revert IdentityDoesNotExist();

        delete _identities[user];
        emit IdentityRevoked(user);
    }

    /*===============================GETTERS===============================*/

    /**
     * @notice Returns full identity data for a user.
     */
    function getIdentity(address user)
        external
        view
        returns (Identity memory)
    {
        if (_identities[user].verifiedTill == 0)
            revert IdentityDoesNotExist();

        return _identities[user];
    }
}

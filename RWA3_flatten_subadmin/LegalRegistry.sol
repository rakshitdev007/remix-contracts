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

// File: RWA3_flatten/LegalRegistry.sol

/*===============================================================
                            INTERFACE
===============================================================*/

/**
 * @title IIdentityRegistry
 * @dev Interface MUST exactly match IdentityRegistry ABI.
 */
interface IIdentityRegistry {
    enum KYCLEVEL {
        none,
        basic,
        enhanced
    }

    enum RISKSCOREBAND {
        low,
        medium,
        high
    }

    enum INVESTORCLASS {
        retail,
        professional,
        accredited
    }

    struct Identity {
        uint256 verifiedTill;
        string identityURI;
        string countryCode;
        KYCLEVEL level;
        RISKSCOREBAND risk;
        INVESTORCLASS class;
    }

    function hasValidIdentity(address user) external view returns (bool);

    function getIdentity(address user)
        external
        view
        returns (Identity memory);
}

/*===============================================================
                          LEGAL REGISTRY
===============================================================*/

/**
 * @title LegalRegistry
 * @author Rakshit Kumar Singh
 * @dev Maintains legal jurisdiction and approval status for RWAs.
 *
 *      - Enforces jurisdiction alignment with verified user identity
 *      - Assets must be approved before tokenization
 */
contract LegalRegistry is Ownable {
    /*===============================ENUMS===============================*/

    enum AssetStatus {
        NONE,
        REQUESTED,
        APPROVED,
        DISAPPROVED
    }

    /*===============================STRUCTS===============================*/

    struct Asset {
        address propertyOwner;
        string countryCode;
        string documentURI;
        AssetStatus status;
    }

    /*===============================STORAGE===============================*/

    mapping(uint256 => Asset) private assets;
    uint256 private _nextAssetId = 1;
    uint256 public totalAssets;

    IIdentityRegistry public immutable identityRegistry;

    /*===============================EVENTS===============================*/

    event AssetRequested(uint256 indexed assetId, address indexed owner);
    event AssetReRequested(uint256 indexed assetId);
    event AssetApproved(uint256 indexed assetId);
    event AssetDisapproved(uint256 indexed assetId, string reason);

    /*===============================ERRORS===============================*/

    error InvalidStatus();
    error NotOwner();
    error IdentityNotVerified();
    error JurisdictionMismatch();

    /*===============================CONSTRUCTOR===============================*/

    constructor(
        address initialOwner,
        address identityRegistryAddress
    ) Ownable(initialOwner) {
        identityRegistry = IIdentityRegistry(identityRegistryAddress);
    }

    /*===============================INTERNAL===============================*/

    /**
     * @dev Validates that the caller has a valid identity and
     *      that the asset jurisdiction matches identity jurisdiction.
     */
    function _validateJurisdiction(
        address user,
        string calldata assetCountry
    ) internal view {
        if (!identityRegistry.hasValidIdentity(user)) {
            revert IdentityNotVerified();
        }

        IIdentityRegistry.Identity memory id =
            identityRegistry.getIdentity(user);

        if (
            keccak256(bytes(id.countryCode)) !=
            keccak256(bytes(assetCountry))
        ) {
            revert JurisdictionMismatch();
        }
    }

    /*===============================USER FUNCTIONS===============================*/

    /**
     * @notice Requests approval for a new asset.
     */
    function requestAsset(
        string calldata countryCode,
        string calldata documentURI
    ) external returns (uint256 assetId) {
        _validateJurisdiction(msg.sender, countryCode);

        assetId = _nextAssetId++;

        assets[assetId] = Asset({
            propertyOwner: msg.sender,
            countryCode: countryCode,
            documentURI: documentURI,
            status: AssetStatus.REQUESTED
        });

        totalAssets++;
        emit AssetRequested(assetId, msg.sender);
    }

    /**
     * @notice Re-requests approval for a previously disapproved asset.
     */
    function reRequestAsset(
        uint256 assetId,
        string calldata countryCode,
        string calldata documentURI
    ) external {
        Asset storage a = assets[assetId];

        if (a.status != AssetStatus.DISAPPROVED) revert InvalidStatus();
        if (a.propertyOwner != msg.sender) revert NotOwner();

        _validateJurisdiction(msg.sender, countryCode);

        a.countryCode = countryCode;
        a.documentURI = documentURI;
        a.status = AssetStatus.REQUESTED;

        emit AssetReRequested(assetId);
    }

    /*===============================ADMIN FUNCTIONS===============================*/

    function approve(uint256 assetId) external onlyOwner {
        if (assets[assetId].status != AssetStatus.REQUESTED)
            revert InvalidStatus();

        assets[assetId].status = AssetStatus.APPROVED;
        emit AssetApproved(assetId);
    }

    function disapprove(
        uint256 assetId,
        string calldata reason
    ) external onlyOwner {
        if (assets[assetId].status != AssetStatus.REQUESTED)
            revert InvalidStatus();

        assets[assetId].status = AssetStatus.DISAPPROVED;
        emit AssetDisapproved(assetId, reason);
    }

    /*===============================VIEWS===============================*/

    function isAssetApproved(uint256 assetId) external view returns (bool) {
        return assets[assetId].status == AssetStatus.APPROVED;
    }

    function getAsset(
        uint256 assetId
    )
        external
        view
        returns (
            address propertyOwner,
            string memory countryCode,
            string memory documentURI,
            AssetStatus status
        )
    {
        Asset storage a = assets[assetId];
        return (a.propertyOwner, a.countryCode, a.documentURI, a.status);
    }
}

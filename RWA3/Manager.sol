// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

/*===============================INTERFACES===============================*/

/**
 * @title ILegalRegistry
 * @dev Interface MUST match LegalRegistry ABI.
 */
interface ILegalRegistry {
    enum AssetStatus {
        NONE,
        REQUESTED,
        APPROVED,
        DISAPPROVED
    }

    function isAssetApproved(uint256 assetId) external view returns (bool);

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
        );
}

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

    function getIdentity(address user) external view returns (Identity memory);
}

/**
 * @title IRWAToken
 * @dev Interface for clone initialization.
 */
interface IRWAToken {
    struct InitParams {
        string name;
        string symbol;
        uint256 assetId;
        address identityRegistry;
        address[] initialOwners;
        uint256[] initialOwnersBalance;
        address propertyManager;
    }

    function initialize(InitParams calldata params) external;
}

/*===============================MANAGER===============================*/

/**
 * @title RwaManager
 * @author Rakshit Kumar Singh
 * @dev Deploys and manages RWA ERC20 token instances (EIP-1167).
 *
 *      - Enforces legal approval via LegalRegistry
 *      - Enforces jurisdiction + identity compliance
 *      - One token per approved asset
 */
contract RwaManager is Ownable {
    using Clones for address;

    /*===============================STORAGE===============================*/

    /// @dev RWA token implementation (EIP-1167)
    address public rwaImplementation;

    /// @dev External registries
    ILegalRegistry public immutable legalRegistry;
    IIdentityRegistry public immutable identityRegistry;

    /// @dev AssetId => RWA token
    mapping(uint256 => address) public rwaByAsset;

    /// @dev List of all deployed RWA tokens
    address[] private _allRWATokens;

    /// @dev Total deployed RWAs
    uint256 public totalRWAs;

    /*===============================EVENTS===============================*/

    event RWACreated(uint256 indexed assetId, address indexed token);
    event RwaImplementationUpdated(
        address indexed oldImpl,
        address indexed newImpl
    );

    /*===============================ERRORS===============================*/

    error ZeroAddress();
    error AssetNotApproved();
    error AlreadyTokenized();
    error InvalidDistribution();
    error IdentityMissing(address user);
    error CountryMismatch(
        address user,
        string identityCountry,
        string assetCountry
    );

    /*===============================CONSTRUCTOR===============================*/

    constructor(
        address implementation_,
        address legalRegistry_,
        address identityRegistry_,
        address initialOwner
    ) Ownable(initialOwner) {
        if (
            implementation_ == address(0) ||
            legalRegistry_ == address(0) ||
            identityRegistry_ == address(0)
        ) revert ZeroAddress();

        rwaImplementation = implementation_;
        legalRegistry = ILegalRegistry(legalRegistry_);
        identityRegistry = IIdentityRegistry(identityRegistry_);
    }

    /*===============================ADMIN===============================*/

    function updateRwaImplementation(address newImpl) external onlyOwner {
        if (newImpl == address(0)) revert ZeroAddress();
        address old = rwaImplementation;
        rwaImplementation = newImpl;
        emit RwaImplementationUpdated(old, newImpl);
    }

    /*===============================CORE LOGIC===============================*/

    /**
     * @notice Creates and initializes an RWA token for an approved asset.
     */
    function createRwa(
        string memory name,
        string memory symbol,
        uint256 assetId,
        address[] calldata initialOwners,
        uint256[] calldata mintAmounts
    ) external returns (address token) {
        /* ---------- Legal Checks ---------- */
        if (!legalRegistry.isAssetApproved(assetId)) revert AssetNotApproved();
        if (rwaByAsset[assetId] != address(0)) revert AlreadyTokenized();

        /* ---------- Fetch Asset ---------- */
        (
            address propertyOwner,
            string memory assetCountry,
            ,
            ILegalRegistry.AssetStatus status
        ) = legalRegistry.getAsset(assetId);

        if (propertyOwner == address(0)) revert ZeroAddress();
        if (status != ILegalRegistry.AssetStatus.APPROVED)
            revert AssetNotApproved();

        /* ---------- Property Owner Compliance ---------- */
        if (!identityRegistry.hasValidIdentity(propertyOwner))
            revert IdentityMissing(propertyOwner);

        IIdentityRegistry.Identity memory ownerId = identityRegistry
            .getIdentity(propertyOwner);

        if (
            keccak256(bytes(ownerId.countryCode)) !=
            keccak256(bytes(assetCountry))
        ) {
            revert CountryMismatch(
                propertyOwner,
                ownerId.countryCode,
                assetCountry
            );
        }

        /* ---------- Distribution Validation ---------- */
        uint256 len = initialOwners.length;
        if (len == 0 || len != mintAmounts.length) revert InvalidDistribution();

        for (uint256 i = 0; i < len; i++) {
            address investor = initialOwners[i];
            if (investor == address(0)) revert ZeroAddress();
            if (!identityRegistry.hasValidIdentity(investor))
                revert IdentityMissing(investor);

            IIdentityRegistry.Identity memory investorId = identityRegistry
                .getIdentity(investor);

            if (
                keccak256(bytes(investorId.countryCode)) !=
                keccak256(bytes(assetCountry))
            ) {
                revert CountryMismatch(
                    investor,
                    investorId.countryCode,
                    assetCountry
                );
            }
        }

        /* ---------- Deploy Clone ---------- */
        token = rwaImplementation.clone();

        IRWAToken.InitParams memory params = IRWAToken.InitParams({
            name: name,
            symbol: symbol,
            assetId: assetId,
            identityRegistry: address(identityRegistry),
            initialOwners: initialOwners,
            initialOwnersBalance: mintAmounts,
            propertyManager: propertyOwner
        });

        IRWAToken(token).initialize(params);

        rwaByAsset[assetId] = token;
        _allRWATokens.push(token);
        totalRWAs++;

        emit RWACreated(assetId, token);
    }

    /*===============================VIEWS===============================*/

    /**
     * @notice Returns all deployed RWA token addresses.
     */
    function getAllRWATokens() external view returns (address[] memory) {
        return _allRWATokens;
    }

    /**
     * @notice Paginated access to deployed RWA tokens.
     */
    function getRWATokens(
        uint256 page,
        uint256 limit
    ) external view returns (address[] memory result) {
        uint256 total = _allRWATokens.length;
        uint256 start = page * limit;
        if (start >= total) return new address[](0);

        uint256 end = start + limit;
        if (end > total) end = total;

        result = new address[](end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = _allRWATokens[i];
        }
    }

    /*===============================ETH HANDLING===============================*/

    receive() external payable {}
    fallback() external payable {}
}

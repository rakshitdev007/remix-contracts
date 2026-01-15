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

    address public rwaImplementation;
    ILegalRegistry public immutable legalRegistry;
    IIdentityRegistry public immutable identityRegistry;

    mapping(uint256 => address) public rwaByAsset;
    address[] private _allRWATokens;
    uint256 public totalRWAs;

    /*===============================EVENTS===============================*/

    event RWACreated(uint256 indexed assetId, address indexed token);
    event RwaImplementationUpdated(
        address indexed oldImpl,
        address indexed newImpl
    );

    /*===============================CONSTRUCTOR===============================*/

    constructor(
        address implementation_,
        address legalRegistry_,
        address identityRegistry_,
        address initialOwner
    ) Ownable(initialOwner) {
        require(implementation_ != address(0), "Zero implementation");
        require(legalRegistry_ != address(0), "Zero legal registry");
        require(identityRegistry_ != address(0), "Zero identity registry");

        rwaImplementation = implementation_;
        legalRegistry = ILegalRegistry(legalRegistry_);
        identityRegistry = IIdentityRegistry(identityRegistry_);
    }

    /*===============================ADMIN===============================*/

    function updateRwaImplementation(address newImpl) external onlyOwner {
        require(newImpl != address(0), "Zero implementation");
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
    ) external onlyOwner returns (address token) {
        /* ---------- Legal Checks ---------- */
        require(
            legalRegistry.isAssetApproved(assetId),
            "Asset not approved"
        );
        require(
            rwaByAsset[assetId] == address(0),
            "Asset already tokenized"
        );

        /* ---------- Fetch Asset ---------- */
        (
            address propertyOwner,
            string memory assetCountry,
            ,
            ILegalRegistry.AssetStatus status
        ) = legalRegistry.getAsset(assetId);

        require(propertyOwner != address(0), "Invalid property owner");
        require(
            status == ILegalRegistry.AssetStatus.APPROVED,
            "Asset not approved"
        );

        /* ---------- Property Owner Compliance ---------- */
        require(
            identityRegistry.hasValidIdentity(propertyOwner),
            "Property owner identity missing"
        );

        IIdentityRegistry.Identity memory ownerId =
            identityRegistry.getIdentity(propertyOwner);

        require(
            keccak256(bytes(ownerId.countryCode)) ==
                keccak256(bytes(assetCountry)),
            "Property owner country mismatch"
        );

        /* ---------- Distribution Validation ---------- */
        uint256 len = initialOwners.length;
        require(len > 0, "Empty distribution");
        require(len == mintAmounts.length, "Invalid distribution length");

        for (uint256 i = 0; i < len; i++) {
            address investor = initialOwners[i];
            require(investor != address(0), "Zero investor");

            require(
                identityRegistry.hasValidIdentity(investor),
                "Investor identity missing"
            );

            IIdentityRegistry.Identity memory investorId =
                identityRegistry.getIdentity(investor);

            require(
                keccak256(bytes(investorId.countryCode)) ==
                    keccak256(bytes(assetCountry)),
                "Investor country mismatch"
            );
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

    function getAllRWATokens() external view returns (address[] memory) {
        return _allRWATokens;
    }

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

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

/*===============================INTERFACES===============================*/

/**
 * @dev Legal registry interface
 * Used to verify asset approval and fetch property owner
 */
interface ILegalRegistry {
    function isAssetApproved(uint256 assetId) external view returns (bool);

    function getAsset(
        uint256 assetId
    )
        external
        view
        returns (
            address propertyOwner,
            string memory jurisdiction,
            string memory documentURI,
            uint8 status
        );
}

/**
 * @dev Identity/KYC registry interface
 */
interface IIdentityRegistry {
    function hasIdentity(address user) external view returns (bool);
}

/**
 * @dev RWAToken interface (MUST match implementation)
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

/**
 * @title RWAManager
 * @author Rakshit Kumar Singh
 * @dev Central factory and governance contract for Real-World Asset (RWA) tokens.
 *
 *      - Verifies legal approval of assets
 *      - Deploys RWAToken clones using EIP-1167
 *      - Injects identity registry internally
 *      - Assigns property owner as token manager
 *      - Tracks total RWAs created
 */
contract RWAManager is Ownable {
    using Clones for address;

    /*===============================STORAGE===============================*/

    /// @notice RWAToken implementation (logic contract)
    address public rwaImplementation;

    /// @notice Legal registry for asset approval
    ILegalRegistry public legalRegistry;

    /// @notice Identity/KYC registry
    IIdentityRegistry public identityRegistry;

    /// @notice assetId => RWAToken clone
    mapping(uint256 => address) public rwaByAsset;

    /// @notice Total number of RWAs created
    uint256 public totalRWAs;

    /*===============================EVENTS===============================*/
    /// @notice Emitted when an RWA is created
    event RWACreated(uint256 indexed assetId, address indexed token);

    /// @notice Emitted when identity registry is updated
    event IdentityRegistryUpdated(
        address indexed oldIdentityRegistry,
        address indexed newIdentityRegistry
    );

    /// @notice Emitted when legal registry is updated
    event LegalRegistryUpdated(
        address indexed oldLegalRegistry,
        address indexed newLegalRegistry
    );

    /// @notice Emitted when legal registry is updated
    event RwaImplementationUpdated(
        address indexed oldRwaImplementation,
        address indexed newRwaImplementation
    );

    /*===============================ERRORS===============================*/

    error ZeroAddress();
    error AssetNotApproved();
    error AlreadyTokenized();
    error InvalidDistribution();
    error IdentityMissing(address user);

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

    /*======================UPDATES======================*/

    /// @notice Update identity registry address
    /// @param newIdentityRegistry New identity registry contract
    function updateIdentityRegistry(
        address newIdentityRegistry
    ) external onlyOwner {
        if (newIdentityRegistry == address(0)) revert ZeroAddress();

        address oldRegistry = address(identityRegistry);
        identityRegistry = IIdentityRegistry(newIdentityRegistry);

        emit IdentityRegistryUpdated(oldRegistry, newIdentityRegistry);
    }

    /// @notice Update legal registry address
    /// @param newLegalRegistry New Legal Registry address
    function updateLegalRegistry(address newLegalRegistry) external onlyOwner {
        if (newLegalRegistry == address(0)) revert ZeroAddress();

        address oldRegistry = address(legalRegistry);
        legalRegistry = ILegalRegistry(newLegalRegistry);

        emit LegalRegistryUpdated(oldRegistry, newLegalRegistry);
    }

    /// @notice Update rwa implementation address
    /// @param newRwaImplementation New Rwa Implementation address
    function updateRwaImplementation(address newRwaImplementation) external onlyOwner {
        if (newRwaImplementation == address(0)) revert ZeroAddress();

        address oldRwaImplementation = rwaImplementation;
        rwaImplementation = newRwaImplementation;

        emit LegalRegistryUpdated(oldRwaImplementation, newRwaImplementation);
    }
    /*===============================CORE LOGIC===============================*/

    /**
     * @notice Creates a new RWA ERC20 token for a legally approved asset
     *
     * @dev
     * - Asset must be approved
     * - Asset can only be tokenized once
     * - Initial balances are provided as absolute mint values
     * - All initial owners must be identity-verified
     *
     * @param name ERC20 name
     * @param symbol ERC20 symbol
     * @param assetId Legal asset identifier
     * @param initialOwners Initial token holders
     * @param mintAmounts Absolute mint amounts per owner
     */
    function createRWA(
        string calldata name,
        string calldata symbol,
        uint256 assetId,
        address[] calldata initialOwners,
        uint256[] calldata mintAmounts
    ) external onlyOwner returns (address token) {
        /* ---------- Legal Checks ---------- */

        if (!legalRegistry.isAssetApproved(assetId)) revert AssetNotApproved();

        if (rwaByAsset[assetId] != address(0)) revert AlreadyTokenized();

        /* ---------- Fetch Property Owner ---------- */

        (address propertyOwner, , , ) = legalRegistry.getAsset(assetId);
        if (propertyOwner == address(0)) revert ZeroAddress();

        /* ---------- Distribution Validation ---------- */

        uint256 ownersLength = initialOwners.length;
        if (ownersLength == 0) revert InvalidDistribution();
        if (ownersLength != mintAmounts.length) revert InvalidDistribution();

        for (uint256 i = 0; i < ownersLength; i++) {
            address owner = initialOwners[i];

            if (owner == address(0)) revert ZeroAddress();
            if (!identityRegistry.hasIdentity(owner))
                revert IdentityMissing(owner);
        }

        /* ---------- Deploy Clone ---------- */

        token = rwaImplementation.clone();

        /* ---------- Initialize Token (stack-safe) ---------- */

        IRWAToken.InitParams memory params;
        params.name = name;
        params.symbol = symbol;
        params.assetId = assetId;
        params.identityRegistry = address(identityRegistry);
        params.initialOwners = initialOwners;
        params.initialOwnersBalance = mintAmounts;
        params.propertyManager = propertyOwner;

        IRWAToken(token).initialize(params);

        /* ---------- Persist State ---------- */

        rwaByAsset[assetId] = token;
        totalRWAs++;

        emit RWACreated(assetId, token);
    }

    /*===============================VIEW HELPERS===============================*/

    function getTotalRWAs() external view returns (uint256) {
        return totalRWAs;
    }

    /*===============================FALLBACKS===============================*/

    receive() external payable {}
    fallback() external payable {}
}

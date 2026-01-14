// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/*===============================================================
                            INTERFACE
===============================================================*/

/**
 * @title IIdentityRegistry
 * @dev Interface MUST exactly match IdentityRegistry ABI.
 */
interface IIdentityRegistry {
    enum kycLevel {
        none,
        basic,
        enhanced
    }

    enum riskScoreBand {
        low,
        medium,
        high
    }

    enum investorClass {
        retail,
        professional,
        accredited
    }

    struct Identity {
        uint256 verifiedTill;
        string identityURI;
        string countryCode;
        kycLevel level;
        riskScoreBand risk;
        investorClass class;
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

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title LegalRegistry
 * @author Rakshit Kumar Singh
 * @dev Maintains legal, jurisdiction, and approval status for real-world assets (RWA).
 *
 *      - Each asset is automatically assigned a unique ID.
 *      - Tracks total number of assets registered.
 *      - Assets must be approved here before tokenization.
 */
contract LegalRegistry is Ownable {
    /**
     * @dev Lifecycle states of an asset in the legal process.
     */
    enum AssetStatus {
        NONE, // Asset does not exist
        REQUESTED, // Submitted by property owner
        APPROVED, // Approved by legal authority
        DISAPPROVED // Rejected by legal authority
    }

    /**
     * @dev Legal metadata associated with an asset.
     */
    struct Asset {
        address propertyOwner; // Owner of the real-world asset
        string jurisdiction; // Country / legal jurisdiction
        string documentURI; // IPFS / URL of legal documents
        AssetStatus status; // Current legal status
    }

    /// @dev Maps assetId => Asset legal data
    mapping(uint256 => Asset) private assets;

    /// @dev Next assetId to assign
    uint256 private _nextAssetId = 1;

    /// @dev Total number of assets ever registered
    uint256 public totalAssets;

    /// @dev Emitted when a new asset is submitted for review
    event AssetRequested(uint256 indexed assetId, address indexed owner);

    /// @dev Emitted when a rejected asset is re-submitted
    event AssetReRequested(uint256 indexed assetId);

    /// @dev Emitted when an asset is approved
    event AssetApproved(uint256 indexed assetId);

    /// @dev Emitted when an asset is disapproved
    event AssetDisapproved(uint256 indexed assetId, string reason);

    error InvalidStatus();
    error NotOwner();

    /**
     * @notice Sets the initial contract owner
     * @param _initialOwner Owner of the registry
     */
    constructor(address _initialOwner) Ownable(_initialOwner) {}

    /**
     * @notice Submit a new asset for legal verification.
     * @dev Auto-assigns a unique incremental assetId.
     *
     * @param jurisdiction Legal jurisdiction (country/state)
     * @param documentURI URI pointing to legal documents
     * @return assetId The auto-generated asset ID
     */
    function requestAsset(
        string calldata jurisdiction,
        string calldata documentURI
    ) external returns (uint256 assetId) {
        assetId = _nextAssetId;
        _nextAssetId++;

        assets[assetId] = Asset({
            propertyOwner: msg.sender,
            jurisdiction: jurisdiction,
            documentURI: documentURI,
            status: AssetStatus.REQUESTED
        });

        totalAssets++;

        emit AssetRequested(assetId, msg.sender);
    }

    /**
     * @notice Re-submit a previously disapproved asset.
     * @dev Only the original property owner can call this.
     *
     * @param assetId Asset identifier
     * @param jurisdiction Updated jurisdiction info
     * @param documentURI Updated legal documents
     */
    function reRequestAsset(
        uint256 assetId,
        string calldata jurisdiction,
        string calldata documentURI
    ) external {
        Asset storage a = assets[assetId];

        if (a.status != AssetStatus.DISAPPROVED) revert InvalidStatus();
        if (a.propertyOwner != msg.sender) revert NotOwner();

        a.jurisdiction = jurisdiction;
        a.documentURI = documentURI;
        a.status = AssetStatus.REQUESTED;

        emit AssetReRequested(assetId);
    }

    /**
     * @notice Approve an asset after legal verification.
     * @dev Callable only by registry authority.
     *
     * @param assetId Asset identifier
     */
    function approve(uint256 assetId) external onlyOwner {
        if (assets[assetId].status != AssetStatus.REQUESTED)
            revert InvalidStatus();

        assets[assetId].status = AssetStatus.APPROVED;
        emit AssetApproved(assetId);
    }

    /**
     * @notice Reject an asset with a reason.
     * @dev Asset can later be re-submitted.
     *
     * @param assetId Asset identifier
     * @param reason Reason for disapproval
     */
    function disapprove(
        uint256 assetId,
        string calldata reason
    ) external onlyOwner {
        if (assets[assetId].status != AssetStatus.REQUESTED)
            revert InvalidStatus();

        assets[assetId].status = AssetStatus.DISAPPROVED;
        emit AssetDisapproved(assetId, reason);
    }

    /**
     * @notice Returns whether an asset is legally approved.
     * @param assetId Asset identifier
     * @return True if approved, false otherwise
     */
    function isAssetApproved(uint256 assetId) external view returns (bool) {
        return assets[assetId].status == AssetStatus.APPROVED;
    }

    /**
     * @notice Returns full asset data for a given ID.
     * @param assetId Asset identifier
     * @return propertyOwner Owner address
     * @return jurisdiction Legal jurisdiction
     * @return documentURI Document URI
     * @return status Current asset status
     */
    function getAsset(
        uint256 assetId
    )
        external
        view
        returns (
            address propertyOwner,
            string memory jurisdiction,
            string memory documentURI,
            AssetStatus status
        )
    {
        Asset storage a = assets[assetId];
        return (a.propertyOwner, a.jurisdiction, a.documentURI, a.status);
    }

    /**
     * @notice Returns the total number of assets ever registered.
     * @return Total registered asset count
     */
    function getTotalAssets() external view returns (uint256) {
        return totalAssets;
    }
}

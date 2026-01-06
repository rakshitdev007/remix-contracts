// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract LegalRegistry is Ownable(msg.sender) {
    struct AssetLegalData {
        string jurisdiction;
        string documentURI;
        bool exists;
    }

    mapping(uint256 => AssetLegalData) private _assets;

    event AssetRegistered(
        uint256 indexed assetId,
        string jurisdiction,
        string documentURI
    );

    function registerAsset(
        uint256 assetId,
        string calldata jurisdiction,
        string calldata documentURI
    ) external onlyOwner {
        require(!_assets[assetId].exists, "ASSET_EXISTS");

        _assets[assetId] = AssetLegalData({
            jurisdiction: jurisdiction,
            documentURI: documentURI,
            exists: true
        });

        emit AssetRegistered(assetId, jurisdiction, documentURI);
    }

    function getAsset(uint256 assetId)
        external
        view
        returns (AssetLegalData memory)
    {
        require(_assets[assetId].exists, "ASSET_NOT_FOUND");
        return _assets[assetId];
    }
}

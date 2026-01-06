// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract LegalAgreementRegistry {
    address public issuer;

    struct Agreement {
        bytes32 documentHash;   // Hash of PDF / deed / prospectus
        string documentURI;     // IPFS / Arweave
        string jurisdiction;    // e.g. "India", "Singapore"
        uint256 effectiveDate;
        bool active;
    }

    Agreement public agreement;

    event AgreementRegistered(bytes32 hash, string uri);
    event AgreementUpdated(bytes32 hash, string uri);

    modifier onlyIssuer() {
        require(msg.sender == issuer, "Only issuer");
        _;
    }

    constructor() {
        issuer = msg.sender;
    }

    function registerAgreement(
        bytes32 _hash,
        string calldata _uri,
        string calldata _jurisdiction
    ) external onlyIssuer {
        agreement = Agreement({
            documentHash: _hash,
            documentURI: _uri,
            jurisdiction: _jurisdiction,
            effectiveDate: block.timestamp,
            active: true
        });

        emit AgreementRegistered(_hash, _uri);
    }

    function updateAgreement(
        bytes32 _newHash,
        string calldata _newURI
    ) external onlyIssuer {
        require(agreement.active, "No active agreement");

        agreement.documentHash = _newHash;
        agreement.documentURI = _newURI;

        emit AgreementUpdated(_newHash, _newURI);
    }
}

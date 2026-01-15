// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/*===============================INTERFACES===============================*/

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

/*===============================TOKEN===============================*/

/**
 * @title RWAToken
 * @author Rakshit Kumar Singh
 * @dev ERC20 token representing fractional ownership of a legally approved RWA.
 *
 *      - Transfers are identity-gated
 *      - Cross-jurisdiction transfers are blocked
 *      - Designed to integrate with LegalRegistry + IdentityRegistry
 */
contract RWAToken is
    Initializable,
    ERC20Upgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    /*===============================STORAGE===============================*/

    uint256 public assetId;
    IIdentityRegistry public identityRegistry;

    /*===============================ERRORS===============================*/

    error ZeroAddress();
    error InvalidDistribution();
    error IdentityRequired(address user);
    error CountryTransferBlocked(
        address from,
        address to,
        string fromCountry,
        string toCountry
    );

    /*===============================INIT PARAMS===============================*/

    struct InitParams {
        string name;
        string symbol;
        uint256 assetId;
        address identityRegistry;
        address[] initialOwners;
        uint256[] initialOwnersBalance;
        address propertyManager;
    }

    /*===============================INITIALIZER===============================*/

    /**
     * @notice Initializes the RWA token instance.
     * @dev Called once by the factory or deployer.
     */
    function initialize(InitParams calldata params) external initializer {
        if (params.identityRegistry == address(0)) revert ZeroAddress();
        if (params.propertyManager == address(0)) revert ZeroAddress();

        uint256 len = params.initialOwners.length;
        if (len == 0 || len != params.initialOwnersBalance.length)
            revert InvalidDistribution();

        __ERC20_init(params.name, params.symbol);
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();

        assetId = params.assetId;
        identityRegistry = IIdentityRegistry(params.identityRegistry);

        for (uint256 i = 0; i < len; i++) {
            address initialOwner = params.initialOwners[i];
            if (initialOwner == address(0)) revert ZeroAddress();

            if (!identityRegistry.hasValidIdentity(initialOwner))
                revert IdentityRequired(initialOwner);

            _mint(initialOwner, params.initialOwnersBalance[i] * 10 ** decimals());
        }

        transferOwnership(params.propertyManager);
    }

    /*===============================TRANSFER HOOK===============================*/

    /**
     * @dev Country + identity gated ERC20 transfer hook.
     *
     * Rules:
     * - Minting allowed only from owner
     * - Burning allowed to zero address
     * - Sender and receiver must both have valid identity
     * - Sender and receiver must belong to the same country
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override {
        // Minting
        if (from == address(0)) {
            super._update(from, to, amount);
            return;
        }
        if (from == address(owner())) {
            super._update(from, to, amount);
            return;
        }

        // Burning
        if (to == address(0)) {
            super._update(from, to, amount);
            return;
        }

        if (to == address(owner())) {
            super._update(from, to, amount);
            return;
        }

        // Identity enforcement
        if (!identityRegistry.hasValidIdentity(from))
            revert IdentityRequired(from);
        if (!identityRegistry.hasValidIdentity(to)) revert IdentityRequired(to);

        // Jurisdiction enforcement
        IIdentityRegistry.Identity memory fromId = identityRegistry.getIdentity(
            from
        );
        IIdentityRegistry.Identity memory toId = identityRegistry.getIdentity(
            to
        );

        if (
            keccak256(bytes(fromId.countryCode)) !=
            keccak256(bytes(toId.countryCode))
        ) {
            revert CountryTransferBlocked(
                from,
                to,
                fromId.countryCode,
                toId.countryCode
            );
        }

        super._update(from, to, amount);
    }

    /*===============================SELL-OUT===============================*/

    /**
     * @notice Allows token holders to redeem tokens for ETH held by the contract.
     * @dev Pro-rata payout based on total supply.
     */
    function sellout(uint256 amount) external nonReentrant {
        address seller = msg.sender;

        if (amount == 0) revert("Amount zero");
        if (balanceOf(seller) < amount) revert("Insufficient token balance");

        uint256 supply = totalSupply();
        uint256 ethBalance = address(this).balance;

        require(supply > 0, "No supply");
        require(ethBalance > 0, "No ETH liquidity");

        uint256 payout = (ethBalance * amount) / supply;
        require(payout > 0, "Payout too small");

        _burn(seller, amount);

        (bool success, ) = seller.call{value: payout}("");
        require(success, "ETH transfer failed");
    }

    /*===============================RECEIVE===============================*/

    receive() external payable {}
}

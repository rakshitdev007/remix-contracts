// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/**
 * @dev External identity registry interface.
 *      Used to enforce on-chain identity / KYC compliance.
 */
interface IIdentityRegistry {
    function hasIdentity(address user) external view returns (bool);
}

/**
 * @title RWAToken
 * @author Rakshit Kumar Singh
 *
 * @notice
 * ERC20 token representing ownership of a single real-world asset (RWA).
 *
 * @dev
 * - One RWAToken instance maps to exactly one `assetId`
 * - Deployed as an EIP-1167 minimal proxy clone
 * - Fully initialized via `initialize()` (constructor is not used)
 * - Initial supply is minted once during initialization
 * - All token transfers are gated by on-chain identity checks
 * - Shareholders are tracked automatically based on token balances
 */
contract RWAToken is
    Initializable,
    ERC20Upgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    /// @notice Legal asset identifier represented by this token
    uint256 public assetId;

    /// @notice Identity registry used for compliance checks
    IIdentityRegistry public identityRegistry;

    /*                 SHAREHOLDER STORAGE                */

    /// @dev List of all current shareholders (balance > 0)
    address[] private _shareholders;

    /// @dev Index of shareholder in `_shareholders` array
    mapping(address => uint256) private _shareholderIndex;

    /// @dev Internal guard to prevent duplicate entries
    mapping(address => bool) private _isShareholder;

    /*                       ERRORS                       */

    /// @dev Thrown when a required address parameter is zero
    error ZeroAddress();

    /// @dev Thrown when initial owner configuration is invalid
    error InvalidDistribution();

    /// @dev Thrown when an address without identity attempts interaction
    error IdentityRequired(address user);

    /*                     INIT PARAMS                    */

    /**
     * @notice Initialization parameters for RWAToken
     *
     * @dev
     * Passed as a single struct to:
     * - Reduce stack usage
     * - Simplify clone initialization
     * - Ensure deterministic ABI encoding
     */
    struct InitParams {
        string name; 
        string symbol; 
        uint256 assetId; // Legal asset identifier
        address identityRegistry; // IdentityRegistry contract
        address[] initialOwners; 
        uint256[] initialOwnersBalance; // Absolute token balances per owner
        address propertyManager; // Token owner / Property manager
    }

    /*                     INITIALIZER                    */

    /**
     * @notice Initializes the RWA token and mints initial balances
     *
     * @dev
     * - Callable only once (protected by `initializer`)
     * - Intended to be called by RWAManager after clone deployment
     * - All initial owners must be identity-verified
     * - Token ownership is assigned to `property manager`
     *
     * @param params Packed initialization parameters
     */
    function initialize(InitParams calldata params) external initializer {
        if (params.identityRegistry == address(0)) revert ZeroAddress();
        if (params.propertyManager == address(0)) revert ZeroAddress();
        if (params.initialOwners.length == 0) revert InvalidDistribution();
        if (params.initialOwners.length != params.initialOwnersBalance.length)
            revert InvalidDistribution();

        // Initialize ERC20 metadata
        __ERC20_init(params.name, params.symbol);

        // Set token owner / property manager
        __Ownable_init(params.propertyManager);

        assetId = params.assetId;
        identityRegistry = IIdentityRegistry(params.identityRegistry);

        // Mint tokens to initial owners
        for (uint256 i = 0; i < params.initialOwners.length; i++) {
            address owner = params.initialOwners[i];

            if (owner == address(0)) revert ZeroAddress();
            if (!identityRegistry.hasIdentity(owner))
                revert IdentityRequired(owner);

            _mint(owner, params.initialOwnersBalance[i] * 10 ** decimals());
        }
    }

    /*                     TRANSFER HOOK                    */

    /**
     * @notice Identity-gated ERC20 transfer hook with shareholder tracking
     *
     * @dev
     * Enforces that:
     * - Sender must have a valid identity (unless minting)
     * - Receiver must have a valid identity (unless burning)
     *
     * Additionally:
     * - Adds an address to shareholders when balance changes 0 → >0
     * - Removes an address from shareholders when balance changes >0 → 0
     */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override {
        if (from != address(0) && !identityRegistry.hasIdentity(from))
            revert IdentityRequired(from);

        if (to != address(0) && !identityRegistry.hasIdentity(to))
            revert IdentityRequired(to);

        uint256 fromBalanceBefore = from == address(0) ? 0 : balanceOf(from);

        uint256 toBalanceBefore = to == address(0) ? 0 : balanceOf(to);

        super._update(from, to, value);

        // Remove shareholder if balance becomes zero
        if (
            from != address(0) && fromBalanceBefore > 0 && balanceOf(from) == 0
        ) {
            _removeShareholder(from);
        }

        // Add shareholder if balance becomes non-zero
        if (to != address(0) && toBalanceBefore == 0 && balanceOf(to) > 0) {
            _addShareholder(to);
        }
    }

    /*                SHAREHOLDER MANAGEMENT               */

    /**
     * @dev Adds an address to the shareholder list
     */
    function _addShareholder(address account) internal {
        if (_isShareholder[account]) return;

        _isShareholder[account] = true;
        _shareholderIndex[account] = _shareholders.length;
        _shareholders.push(account);
    }

    /**
     * @dev Removes an address from the shareholder list
     */
    function _removeShareholder(address account) internal {
        if (!_isShareholder[account]) return;

        uint256 index = _shareholderIndex[account];
        uint256 lastIndex = _shareholders.length - 1;

        if (index != lastIndex) {
            address last = _shareholders[lastIndex];
            _shareholders[index] = last;
            _shareholderIndex[last] = index;
        }

        _shareholders.pop();
        delete _shareholderIndex[account];
        delete _isShareholder[account];
    }

    /**
     * @notice Returns the list of all current shareholders
     */
    function getShareholders() external view returns (address[] memory) {
        return _shareholders;
    }

    /**
     * @notice Allows a token holder to sell their tokens back to the contract
     *         in exchange for native chain currency (ETH / BNB / MATIC).
     *
     * @dev
     * - Payout is calculated proportionally based on:
     *   (contract ETH balance * token amount) / total token supply
     * - Tokens are burned before ETH is transferred (checks-effects-interactions)
     * - Uses `nonReentrant` to protect against reentrancy attacks
     *
     * @param amount Number of tokens to sell (in smallest ERC20 units)
     */
    function sellout(uint256 amount) external nonReentrant {
        address stakeHolder = msg.sender;

        if (amount == 0) revert("Amount zero");
        if (balanceOf(stakeHolder) < amount)
            revert("Insufficient token balance");

        uint256 supply = totalSupply();
        uint256 ethBalance = address(this).balance;

        require(supply > 0, "No supply");
        require(ethBalance > 0, "No ETH liquidity");

        uint256 payout = (ethBalance * amount) / supply;
        require(payout > 0, "Payout too small");

        // Burn first (effects)
        _burn(stakeHolder, amount);

        // Interactions last
        (bool success, ) = stakeHolder.call{value: payout}("");
        require(success, "ETH transfer failed");
    }

    /**
     * @notice Withdraws native chain currency from the contract and distributes
     *         it proportionally to all current shareholders.
     *
     * @dev
     * - Distribution is based on each holder’s token balance relative to total supply
     * - Only addresses with balance > 0 are considered shareholders
     * - Uses checks-effects-interactions pattern
     *
     * Requirements:
     * - `amount` must be greater than zero
     * - Contract must have sufficient native token balance
     * - Token supply must be non-zero
     *
     * @param amount Amount of native currency to distribute
     */
    function withdrawValue(uint256 amount) external onlyOwner nonReentrant {
        uint256 ethBalance = address(this).balance;
        require(amount > 0, "Amount zero");
        require(ethBalance >= amount, "Insufficient liquidity");

        uint256 supply = totalSupply();
        require(supply > 0, "No token supply");

        uint256 shareholdersLength = _shareholders.length;
        require(shareholdersLength > 0, "No shareholders");

        // Effects: reserve amount by reducing local balance reference
        uint256 remaining = amount;

        // Interactions: distribute proportionally
        for (uint256 i = 0; i < shareholdersLength; i++) {
            address shareholder = _shareholders[i];
            uint256 holderBalance = balanceOf(shareholder);

            if (holderBalance == 0) continue;

            uint256 payout = (amount * holderBalance) / supply;
            if (payout == 0) continue;

            remaining -= payout;

            (bool success, ) = shareholder.call{value: payout}("");
            require(success, "ETH transfer failed");
        }
    }

    /**
     * @notice Accept native token deposits (rent, yield, revenue, etc.)
     */
    receive() external payable {}
}


/************************************************************************************************
         user < 50  Safe
    50 < user < 200 Risk
         user > 200 Will fail
************************************************************************************************/
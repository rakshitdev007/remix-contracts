// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/ICompliance.sol";

/**
 * @title ComplianceExemption
 * @dev Manages exemptions for compliance checks allowing specific addresses to bypass certain rules
 * @notice Supports global and module-specific exemptions with optional expiry times
 */
contract ComplianceExemption is Ownable {
    /// @dev Exemption data structure
    struct Exemption {
        bool isExempt;
        uint256 expiryTime; // 0 for permanent exemption
    }
    
    /// @dev The compliance contract this exemption manager is for
    ICompliance public immutable compliance;
    
    /// @dev Mapping of account => module => exemption
    /// address(0) for module means global exemption
    mapping(address => mapping(address => Exemption)) private _exemptions;
    
    /// @dev Mapping of authorized agents who can manage exemptions
    mapping(address => bool) private _agents;
    
    /// @dev Events
    event ExemptionAdded(address indexed account, address indexed module, uint256 expiryTime);
    event ExemptionRemoved(address indexed account, address indexed module);
    event AgentAdded(address indexed agent);
    event AgentRemoved(address indexed agent);
    
    /// @dev Errors
    error OnlyOwnerOrAgent();
    error InvalidExpiryTime();
    error ZeroAddress();
    
    /// @dev Modifier to restrict access to owner or agents
    modifier onlyOwnerOrAgent() {
        if (msg.sender != owner() && !_agents[msg.sender]) {
            revert OnlyOwnerOrAgent();
        }
        _;
    }
    
    /**
     * @dev Constructor
     * @param _compliance Address of the compliance contract
     */
    constructor(address _compliance) Ownable(msg.sender) {
        if (_compliance == address(0)) revert ZeroAddress();
        compliance = ICompliance(_compliance);
    }
    
    /**
     * @notice Add an agent who can manage exemptions
     * @param agent Address of the agent to add
     */
    function addAgent(address agent) external onlyOwner {
        if (agent == address(0)) revert ZeroAddress();
        _agents[agent] = true;
        emit AgentAdded(agent);
    }
    
    /**
     * @notice Remove an agent
     * @param agent Address of the agent to remove
     */
    function removeAgent(address agent) external onlyOwner {
        _agents[agent] = false;
        emit AgentRemoved(agent);
    }
    
    /**
     * @notice Check if an address is an agent
     * @param agent Address to check
     * @return True if the address is an agent
     */
    function isAgent(address agent) external view returns (bool) {
        return _agents[agent];
    }
    
    /**
     * @notice Add an exemption for an account
     * @param account Address to grant exemption to
     * @param module Module address (address(0) for global exemption)
     * @param expiryTime Expiry timestamp (0 for permanent exemption)
     */
    function addExemption(
        address account,
        address module,
        uint256 expiryTime
    ) external onlyOwnerOrAgent {
        if (account == address(0)) revert ZeroAddress();
        if (expiryTime > 0 && expiryTime <= block.timestamp) {
            revert InvalidExpiryTime();
        }
        
        _exemptions[account][module] = Exemption({
            isExempt: true,
            expiryTime: expiryTime
        });
        
        emit ExemptionAdded(account, module, expiryTime);
    }
    
    /**
     * @notice Remove an exemption for an account
     * @param account Address to revoke exemption from
     * @param module Module address (address(0) for global exemption)
     */
    function removeExemption(
        address account,
        address module
    ) external onlyOwnerOrAgent {
        delete _exemptions[account][module];
        emit ExemptionRemoved(account, module);
    }
    
    /**
     * @notice Check if an account is exempt for a specific module
     * @param account Address to check
     * @param module Module address
     * @return True if the account is exempt
     */
    function isExempt(address account, address module) public view returns (bool) {
        // Check global exemption first
        Exemption memory globalExemption = _exemptions[account][address(0)];
        if (globalExemption.isExempt) {
            if (globalExemption.expiryTime == 0 || globalExemption.expiryTime > block.timestamp) {
                return true;
            }
        }
        
        // Check module-specific exemption
        Exemption memory moduleExemption = _exemptions[account][module];
        if (moduleExemption.isExempt) {
            if (moduleExemption.expiryTime == 0 || moduleExemption.expiryTime > block.timestamp) {
                return true;
            }
        }
        
        return false;
    }
    
    /**
     * @notice Get exemption information for an account and module
     * @param account Address to check
     * @param module Module address
     * @return isExempt True if currently exempt
     * @return expiryTime Expiry timestamp (0 for permanent)
     */
    function getExemptionInfo(
        address account,
        address module
    ) external view returns (bool isExempt, uint256 expiryTime) {
        Exemption memory exemption = _exemptions[account][module];
        
        // Check if exemption is still valid
        if (exemption.isExempt) {
            if (exemption.expiryTime == 0 || exemption.expiryTime > block.timestamp) {
                return (true, exemption.expiryTime);
            }
        }
        
        return (false, 0);
    }
    
    /**
     * @notice Check if a transfer should be allowed considering exemptions
     * @param from Sender address
     * @param to Receiver address
     * @param amount Transfer amount
     * @return True if transfer is allowed
     */
    function canTransferWithExemption(
        address from,
        address to,
        uint256 amount
    ) external view returns (bool) {
        // If either party is globally exempt, allow
        if (isExempt(from, address(0)) || isExempt(to, address(0))) {
            return true;
        }
        
        // Otherwise check compliance
        return compliance.canTransfer(from, to, amount);
    }
}

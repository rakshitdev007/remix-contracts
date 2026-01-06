// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/ICompliance.sol";
import "../interfaces/IComplianceModule.sol";

/**
 * @title ComplianceComposer
 * @dev Advanced compliance engine supporting AND/OR logic composition
 * @notice Allows complex boolean expressions for compliance rules
 */
contract ComplianceComposer is ICompliance, Ownable {
    /// @dev Logic operators for rule composition
    enum LogicOperator {
        AND,
        OR
    }
    
    /// @dev Rule structure
    struct Rule {
        LogicOperator operator;
        address[] modules;      // For simple rules
        uint256[] childRules;   // For composite rules
        bool isComposite;
        bool exists;
    }
    
    /// @dev Address of the bound token
    address private _token;
    
    /// @dev Rule storage
    mapping(uint256 => Rule) private _rules;
    uint256 private _nextRuleId;
    
    /// @dev Failure tracking for error reporting
    mapping(uint256 => string) private _lastFailureReasons;
    
    /// @dev Events
    event RuleCreated(uint256 indexed ruleId, LogicOperator operator, bool isComposite);
    event RuleUpdated(uint256 indexed ruleId);
    event RuleEvaluated(uint256 indexed ruleId, bool result);
    event ComplianceCheckFailed(uint256 indexed ruleId, string reason);
    
    /// @dev Errors
    error TokenNotBound();
    error OnlyToken();
    error InvalidRule();
    error RuleNotFound();
    error EmptyModuleList();
    
    /**
     * @dev Modifier to restrict access to bound token only
     */
    modifier onlyToken() {
        if (msg.sender != _token) revert OnlyToken();
        _;
    }
    
    constructor() Ownable(msg.sender) {
        _nextRuleId = 1;
    }
    
    /**
     * @notice Bind this compliance to a token
     * @param token Address of the token to bind
     */
    function bindToken(address token) external onlyOwner {
        _token = token;
        emit TokenBound(token);
    }
    
    /**
     * @notice Unbind the token
     */
    function unbindToken(address /* token */) external override onlyOwner {
        _token = address(0);
    }
    
    /**
     * @notice Create an AND rule (all modules must pass)
     * @param modules Array of module addresses
     * @return ruleId The ID of the created rule
     */
    function createAndRule(address[] memory modules) external onlyOwner returns (uint256) {
        if (modules.length == 0) revert EmptyModuleList();
        
        uint256 ruleId = _nextRuleId++;
        
        Rule storage rule = _rules[ruleId];
        rule.operator = LogicOperator.AND;
        rule.modules = modules;
        rule.isComposite = false;
        rule.exists = true;
        
        emit RuleCreated(ruleId, LogicOperator.AND, false);
        return ruleId;
    }
    
    /**
     * @notice Create an OR rule (any module can pass)
     * @param modules Array of module addresses
     * @return ruleId The ID of the created rule
     */
    function createOrRule(address[] memory modules) external onlyOwner returns (uint256) {
        if (modules.length == 0) revert EmptyModuleList();
        
        uint256 ruleId = _nextRuleId++;
        
        Rule storage rule = _rules[ruleId];
        rule.operator = LogicOperator.OR;
        rule.modules = modules;
        rule.isComposite = false;
        rule.exists = true;
        
        emit RuleCreated(ruleId, LogicOperator.OR, false);
        return ruleId;
    }
    
    /**
     * @notice Create a composite AND rule (all child rules must pass)
     * @param childRules Array of child rule IDs
     * @return ruleId The ID of the created composite rule
     */
    function createCompositeAndRule(uint256[] memory childRules) external onlyOwner returns (uint256) {
        if (childRules.length == 0) revert EmptyModuleList();
        
        // Validate child rules exist
        for (uint256 i = 0; i < childRules.length; i++) {
            if (!_rules[childRules[i]].exists) revert RuleNotFound();
        }
        
        uint256 ruleId = _nextRuleId++;
        
        Rule storage rule = _rules[ruleId];
        rule.operator = LogicOperator.AND;
        rule.childRules = childRules;
        rule.isComposite = true;
        rule.exists = true;
        
        emit RuleCreated(ruleId, LogicOperator.AND, true);
        return ruleId;
    }
    
    /**
     * @notice Create a composite OR rule (any child rule can pass)
     * @param childRules Array of child rule IDs
     * @return ruleId The ID of the created composite rule
     */
    function createCompositeOrRule(uint256[] memory childRules) external onlyOwner returns (uint256) {
        if (childRules.length == 0) revert EmptyModuleList();
        
        // Validate child rules exist
        for (uint256 i = 0; i < childRules.length; i++) {
            if (!_rules[childRules[i]].exists) revert RuleNotFound();
        }
        
        uint256 ruleId = _nextRuleId++;
        
        Rule storage rule = _rules[ruleId];
        rule.operator = LogicOperator.OR;
        rule.childRules = childRules;
        rule.isComposite = true;
        rule.exists = true;
        
        emit RuleCreated(ruleId, LogicOperator.OR, true);
        return ruleId;
    }
    
    /**
     * @notice Evaluate a rule
     * @param ruleId ID of the rule to evaluate
     * @param from Sender address
     * @param to Receiver address
     * @param amount Transfer amount
     * @return True if rule passes
     */
    function evaluateRule(
        uint256 ruleId,
        address from,
        address to,
        uint256 amount
    ) public view returns (bool) {
        Rule storage rule = _rules[ruleId];
        if (!rule.exists) revert RuleNotFound();
        
        if (rule.isComposite) {
            return _evaluateCompositeRule(rule, from, to, amount);
        } else {
            return _evaluateSimpleRule(rule, from, to, amount);
        }
    }
    
    /**
     * @dev Evaluate a simple rule (modules)
     */
    function _evaluateSimpleRule(
        Rule storage rule,
        address from,
        address to,
        uint256 amount
    ) private view returns (bool) {
        if (rule.operator == LogicOperator.AND) {
            // All modules must pass - short circuit on first failure
            for (uint256 i = 0; i < rule.modules.length; i++) {
                if (!IComplianceModule(rule.modules[i]).canTransfer(from, to, amount)) {
                    return false;
                }
            }
            return true;
        } else {
            // Any module can pass - short circuit on first success
            for (uint256 i = 0; i < rule.modules.length; i++) {
                if (IComplianceModule(rule.modules[i]).canTransfer(from, to, amount)) {
                    return true;
                }
            }
            return false;
        }
    }
    
    /**
     * @dev Evaluate a composite rule (child rules)
     */
    function _evaluateCompositeRule(
        Rule storage rule,
        address from,
        address to,
        uint256 amount
    ) private view returns (bool) {
        if (rule.operator == LogicOperator.AND) {
            // All child rules must pass - short circuit on first failure
            for (uint256 i = 0; i < rule.childRules.length; i++) {
                if (!evaluateRule(rule.childRules[i], from, to, amount)) {
                    return false;
                }
            }
            return true;
        } else {
            // Any child rule can pass - short circuit on first success
            for (uint256 i = 0; i < rule.childRules.length; i++) {
                if (evaluateRule(rule.childRules[i], from, to, amount)) {
                    return true;
                }
            }
            return false;
        }
    }
    
    /**
     * @notice Update a rule's modules
     * @param ruleId ID of the rule to update
     * @param modules New array of module addresses
     */
    function updateRule(uint256 ruleId, address[] memory modules) external onlyOwner {
        Rule storage rule = _rules[ruleId];
        if (!rule.exists) revert RuleNotFound();
        if (rule.isComposite) revert InvalidRule();
        if (modules.length == 0) revert EmptyModuleList();
        
        rule.modules = modules;
        emit RuleUpdated(ruleId);
    }
    
    /**
     * @notice Get information about a rule
     * @param ruleId ID of the rule
     * @return operator Logic operator of the rule
     * @return moduleCount Number of modules/child rules
     * @return isComposite Whether the rule is composite
     */
    function getRuleInfo(uint256 ruleId) external view returns (
        LogicOperator operator,
        uint256 moduleCount,
        bool isComposite
    ) {
        Rule storage rule = _rules[ruleId];
        if (!rule.exists) revert RuleNotFound();
        
        operator = rule.operator;
        isComposite = rule.isComposite;
        
        if (isComposite) {
            moduleCount = rule.childRules.length;
        } else {
            moduleCount = rule.modules.length;
        }
    }
    
    /**
     * @notice Get the last failure reason for a rule
     * @param ruleId ID of the rule
     * @return Failure reason string
     */
    function getLastFailureReason(uint256 ruleId) external view returns (string memory) {
        return _lastFailureReasons[ruleId];
    }
    
    /**
     * @notice Get the bound token address
     * @return Address of the bound token
     */
    function tokenBound() external view returns (address) {
        return _token;
    }
    
    /**
     * @notice Add a module (not used in composer pattern)
     * @dev This function exists for interface compatibility but doesn't apply to composer
     */
    function addModule(address /* _module */) external override onlyOwner {
        revert InvalidRule();
    }
    
    /**
     * @notice Remove a module (not used in composer pattern)
     * @dev This function exists for interface compatibility but doesn't apply to composer
     */
    function removeModule(address /* _module */) external override onlyOwner {
        revert InvalidRule();
    }
    
    /**
     * @notice Check if a module is bound
     * @return Always returns false as composer doesn't use module binding
     */
    function isModuleBound(address /* _module */) external pure override returns (bool) {
        return false;
    }
    
    /**
     * @notice Check if a token is bound
     * @param __token Token address to check
     * @return True if token is bound
     */
    function isTokenBound(address __token) external view override returns (bool) {
        return _token == __token;
    }
    
    // ========== ICompliance Interface Implementation ==========
    
    /**
     * @notice Check if a transfer is compliant (uses default rule ID 1)
     * @param from Sender address
     * @param to Receiver address
     * @param amount Transfer amount
     * @return True if transfer is allowed
     */
    function canTransfer(
        address from,
        address to,
        uint256 amount
    ) external view override returns (bool) {
        // Use rule ID 1 as the default main rule
        if (!_rules[1].exists) return true;
        return evaluateRule(1, from, to, amount);
    }
    
    /**
     * @notice Called after a successful transfer
     * @param from Sender address
     * @param to Receiver address
     * @param amount Transfer amount
     */
    function transferred(
        address from,
        address to,
        uint256 amount
    ) external override onlyToken {
        // Notify all modules in the main rule
        if (_rules[1].exists && !_rules[1].isComposite) {
            for (uint256 i = 0; i < _rules[1].modules.length; i++) {
                IComplianceModule(_rules[1].modules[i]).transferred(from, to, amount);
            }
        }
    }
    
    /**
     * @notice Called when tokens are created
     * @param to Receiver address
     * @param amount Amount created
     */
    function created(address to, uint256 amount) external override onlyToken {
        // Notify all modules in the main rule
        if (_rules[1].exists && !_rules[1].isComposite) {
            for (uint256 i = 0; i < _rules[1].modules.length; i++) {
                IComplianceModule(_rules[1].modules[i]).created(to, amount);
            }
        }
    }
    
    /**
     * @notice Called when tokens are destroyed
     * @param from Sender address
     * @param amount Amount destroyed
     */
    function destroyed(address from, uint256 amount) external override onlyToken {
        // Notify all modules in the main rule
        if (_rules[1].exists && !_rules[1].isComposite) {
            for (uint256 i = 0; i < _rules[1].modules.length; i++) {
                IComplianceModule(_rules[1].modules[i]).destroyed(from, amount);
            }
        }
    }
}

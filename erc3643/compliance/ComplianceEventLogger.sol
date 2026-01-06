// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/ICompliance.sol";

/**
 * @title ComplianceEventLogger
 * @dev Enhanced compliance wrapper with comprehensive event logging for audit trails
 * @notice Wraps any ICompliance implementation to add detailed event logging
 */
contract ComplianceEventLogger is ICompliance, Ownable {
    /// @dev Error codes for compliance failures
    enum ErrorCode {
        NONE,
        IDENTITY_NOT_VERIFIED,
        HOLDER_LIMIT_EXCEEDED,
        BALANCE_LIMIT_EXCEEDED,
        COUNTRY_RESTRICTED,
        TIME_RESTRICTED,
        MODULE_REJECTION,
        PAUSED,
        FROZEN,
        CUSTOM
    }
    
    /// @dev The underlying compliance contract
    ICompliance public immutable compliance;
    
    /// @dev Enable/disable event logging
    bool public loggingEnabled;
    
    /// @dev Events for compliance checks
    event ComplianceCheckPassed(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 timestamp,
        string context
    );
    
    event ComplianceCheckFailed(
        address indexed from,
        address indexed to,
        uint256 amount,
        ErrorCode errorCode,
        string reason,
        uint256 timestamp
    );
    
    event ComplianceModuleTriggered(
        address indexed module,
        address indexed from,
        address indexed to,
        uint256 amount,
        bool passed,
        uint256 timestamp
    );
    
    event TransferCompleted(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 timestamp
    );
    
    event TokensCreated(
        address indexed to,
        uint256 amount,
        uint256 timestamp
    );
    
    event TokensDestroyed(
        address indexed from,
        uint256 amount,
        uint256 timestamp
    );
    
    event LoggingStatusChanged(bool enabled);
    
    /// @dev Errors
    error LoggingDisabled();
    
    /**
     * @dev Constructor
     * @param _compliance Address of the underlying compliance contract
     */
    constructor(address _compliance) Ownable(msg.sender) {
        compliance = ICompliance(_compliance);
        loggingEnabled = true;
    }
    
    /**
     * @notice Enable or disable event logging
     * @param enabled True to enable logging, false to disable
     */
    function setLoggingEnabled(bool enabled) external onlyOwner {
        loggingEnabled = enabled;
        emit LoggingStatusChanged(enabled);
    }
    
    /**
     * @notice Check if a transfer is compliant with logging
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
        return compliance.canTransfer(from, to, amount);
    }
    
    /**
     * @notice Check compliance and emit detailed events
     * @param from Sender address
     * @param to Receiver address
     * @param amount Transfer amount
     * @param context Additional context for the check
     * @return True if compliant
     */
    function checkAndLog(
        address from,
        address to,
        uint256 amount,
        string calldata context
    ) external returns (bool) {
        bool result = compliance.canTransfer(from, to, amount);
        
        if (loggingEnabled) {
            if (result) {
                emit ComplianceCheckPassed(from, to, amount, block.timestamp, context);
            } else {
                emit ComplianceCheckFailed(
                    from,
                    to,
                    amount,
                    ErrorCode.MODULE_REJECTION,
                    "Compliance check failed",
                    block.timestamp
                );
            }
        }
        
        return result;
    }
    
    /**
     * @notice Log compliance check failure with specific error code
     * @param from Sender address
     * @param to Receiver address
     * @param amount Transfer amount
     * @param errorCode Specific error code
     * @param reason Human-readable reason
     */
    function logFailure(
        address from,
        address to,
        uint256 amount,
        ErrorCode errorCode,
        string calldata reason
    ) external {
        if (!loggingEnabled) revert LoggingDisabled();
        
        emit ComplianceCheckFailed(
            from,
            to,
            amount,
            errorCode,
            reason,
            block.timestamp
        );
    }
    
    /**
     * @notice Log module evaluation
     * @param module Module address
     * @param from Sender address
     * @param to Receiver address
     * @param amount Transfer amount
     * @param passed Whether the module check passed
     */
    function logModuleCheck(
        address module,
        address from,
        address to,
        uint256 amount,
        bool passed
    ) external {
        if (!loggingEnabled) revert LoggingDisabled();
        
        emit ComplianceModuleTriggered(
            module,
            from,
            to,
            amount,
            passed,
            block.timestamp
        );
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
    ) external override {
        if (loggingEnabled) {
            emit TransferCompleted(from, to, amount, block.timestamp);
        }
    }
    
    /**
     * @notice Called when tokens are created
     * @param to Receiver address
     * @param amount Amount created
     */
    function created(address to, uint256 amount) external override {
        if (loggingEnabled) {
            emit TokensCreated(to, amount, block.timestamp);
        }
    }
    
    /**
     * @notice Called when tokens are destroyed
     * @param from Sender address
     * @param amount Amount destroyed
     */
    function destroyed(address from, uint256 amount) external override {
        if (loggingEnabled) {
            emit TokensDestroyed(from, amount, block.timestamp);
        }
    }
    
    /**
     * @notice Add a module to the underlying compliance
     * @param _module Module address
     */
    function addModule(address _module) external override onlyOwner {
        compliance.addModule(_module);
    }
    
    /**
     * @notice Remove a module from the underlying compliance
     * @param _module Module address
     */
    function removeModule(address _module) external override onlyOwner {
        compliance.removeModule(_module);
    }
    
    /**
     * @notice Unbind the token
     * @param _token Token address
     */
    function unbindToken(address _token) external override onlyOwner {
        compliance.unbindToken(_token);
    }
    
    /**
     * @notice Bind this compliance to a token
     * @dev This is a passthrough - the underlying compliance must already be bound
     * @param _token Token address
     */
    function bindToken(address _token) external view onlyOwner {
        // Verify underlying compliance is bound
        require(compliance.isTokenBound(_token), "Underlying compliance not bound");
    }
    
    /**
     * @notice Check if a module is bound
     * @param _module Module address
     * @return True if module is bound
     */
    function isModuleBound(address _module) external view override returns (bool) {
        return compliance.isModuleBound(_module);
    }
    
    /**
     * @notice Check if a token is bound
     * @param _token Token address
     * @return True if token is bound
     */
    function isTokenBound(address _token) external view override returns (bool) {
        return compliance.isTokenBound(_token);
    }
}

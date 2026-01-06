// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "./ModularCompliance.sol";
import "./modules/MaxHoldersModule.sol";
import "./modules/MaxBalanceModule.sol";
import "./modules/CountryRestrictionsModule.sol";
import "./modules/TimeRestrictionsModule.sol";

/**
 * @title CompliancePresets
 * @dev Factory for deploying pre-configured compliance templates for common regulatory scenarios
 * @notice Provides RegD, RegS, and MiFID II compliance presets
 */
contract CompliancePresets {
    /// @dev Preset information
    struct PresetInfo {
        string name;
        string description;
        uint256 expectedModules;
    }
    
    /// @dev Mapping of preset names to their info
    mapping(string => PresetInfo) private presetInfoMap;
    
    /// @dev Events
    event PresetDeployed(string indexed presetName, address indexed compliance);
    
    /// @dev Errors
    error InvalidPresetName();
    error PresetNotFound();
    
    constructor() {
        // Initialize preset metadata
        presetInfoMap["RegD"] = PresetInfo({
            name: "RegD",
            description: "SEC Regulation D - US accredited investors with 2000 holder limit",
            expectedModules: 1
        });
        
        presetInfoMap["RegS"] = PresetInfo({
            name: "RegS",
            description: "SEC Regulation S - Non-US investors, excludes US persons",
            expectedModules: 1
        });
        
        presetInfoMap["MiFID_II"] = PresetInfo({
            name: "MiFID_II",
            description: "EU MiFID II - European compliance with balance and holder limits",
            expectedModules: 2
        });
    }
    
    /**
     * @dev Deploy RegD compliant configuration
     * @return Address of deployed ModularCompliance contract
     * @notice RegD: Max 2000 holders (accredited investors)
     */
    function deployRegDPreset() external returns (address) {
        ModularCompliance compliance = new ModularCompliance();
        
        // RegD typically has a 2000 holder limit for accredited investors
        MaxHoldersModule maxHoldersModule = new MaxHoldersModule(address(compliance));
        maxHoldersModule.setHolderLimit(2000);
        
        compliance.addModule(address(maxHoldersModule));
        compliance.transferOwnership(msg.sender);
        
        emit PresetDeployed("RegD", address(compliance));
        return address(compliance);
    }
    
    /**
     * @dev Deploy RegS compliant configuration
     * @return Address of deployed ModularCompliance contract
     * @notice RegS: Excludes US investors (country code 840)
     */
    function deployRegSPreset() external returns (address) {
        ModularCompliance compliance = new ModularCompliance();
        
        // RegS excludes US persons
        CountryRestrictionsModule countryModule = new CountryRestrictionsModule(address(compliance));
        
        // Restrict US (country code 840)
        countryModule.blacklistCountry(840); // USA
        
        compliance.addModule(address(countryModule));
        compliance.transferOwnership(msg.sender);
        
        emit PresetDeployed("RegS", address(compliance));
        return address(compliance);
    }
    
    /**
     * @dev Deploy MiFID II compliant configuration
     * @return Address of deployed ModularCompliance contract
     * @notice MiFID II: EU compliance with balance and holder limits
     */
    function deployMiFIDIIPreset() external returns (address) {
        ModularCompliance compliance = new ModularCompliance();
        
        // MiFID II typically has holder limits
        MaxHoldersModule maxHoldersModule = new MaxHoldersModule(address(compliance));
        maxHoldersModule.setHolderLimit(5000); // EU retail investor limit
        
        // MiFID II also has balance limits for retail investors
        MaxBalanceModule maxBalanceModule = new MaxBalanceModule(address(compliance));
        maxBalanceModule.setMaxBalance(100000 ether); // Example: 100k token limit
        
        compliance.addModule(address(maxHoldersModule));
        compliance.addModule(address(maxBalanceModule));
        compliance.transferOwnership(msg.sender);
        
        emit PresetDeployed("MiFID_II", address(compliance));
        return address(compliance);
    }
    
    /**
     * @dev Get information about a preset
     * @param presetName Name of the preset
     * @return name Preset name
     * @return description Preset description
     * @return expectedModules Number of modules in preset
     */
    function getPresetInfo(string memory presetName) 
        external 
        view 
        returns (
            string memory name,
            string memory description,
            uint256 expectedModules
        ) 
    {
        PresetInfo memory info = presetInfoMap[presetName];
        
        if (bytes(info.name).length == 0) {
            revert PresetNotFound();
        }
        
        return (info.name, info.description, info.expectedModules);
    }
    
    /**
     * @dev Check if a preset exists
     * @param presetName Name to check
     * @return True if preset exists
     */
    function presetExists(string memory presetName) external view returns (bool) {
        return bytes(presetInfoMap[presetName].name).length > 0;
    }
}

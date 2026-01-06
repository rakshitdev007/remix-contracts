// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "../interfaces/IClaimTopicsRegistry.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ClaimTopicsRegistry
 * @dev Implementation of Claim Topics Registry
 * @notice Defines required claim types for token holders
 */
contract ClaimTopicsRegistry is IClaimTopicsRegistry, Ownable { // https://testnet.bscscan.com/address/0x8d2bbAfff80193e89756039e13aad3EAa96F2668#code
    /// @dev Array of required claim topics
    uint256[] private claimTopics;
    
    /// @dev Mapping to track if a topic exists
    mapping(uint256 => bool) private topicExists;
    
    /**
     * @dev Custom errors for gas efficiency
     */
    error TopicAlreadyExists();
    error TopicDoesNotExist();
    
    /**
     * @dev Constructor
     */
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Add a claim topic to the registry
     * @param claimTopic The claim topic to add
     */
    function addClaimTopic(uint256 claimTopic) external override onlyOwner {
        if (topicExists[claimTopic]) revert TopicAlreadyExists();
        
        claimTopics.push(claimTopic);
        topicExists[claimTopic] = true;
        
        emit ClaimTopicAdded(claimTopic);
    }
    
    /**
     * @dev Remove a claim topic from the registry
     * @param claimTopic The claim topic to remove
     */
    function removeClaimTopic(uint256 claimTopic) external override onlyOwner {
        if (!topicExists[claimTopic]) revert TopicDoesNotExist();
        
        // Find and remove the topic from array
        for (uint256 i = 0; i < claimTopics.length; i++) {
            if (claimTopics[i] == claimTopic) {
                // Move last element to current position and pop
                claimTopics[i] = claimTopics[claimTopics.length - 1];
                claimTopics.pop();
                break;
            }
        }
        
        topicExists[claimTopic] = false;
        
        emit ClaimTopicRemoved(claimTopic);
    }
    
    /**
     * @dev Get all required claim topics
     * @return Array of all required claim topics
     */
    function getClaimTopics() external view override returns (uint256[] memory) {
        return claimTopics;
    }
}

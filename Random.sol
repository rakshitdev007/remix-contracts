pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

contract RandomNumber is VRFConsumerBaseV2 {
    VRFCoordinatorV2Interface COORDINATOR;
    uint64 subscriptionId;
    bytes32 keyHash;
    uint256 public randomNumber;

    constructor(uint64 _subscriptionId, address _vrfCoordinator, bytes32 _keyHash) 
        VRFConsumerBaseV2(_vrfCoordinator)
    {
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
        subscriptionId = _subscriptionId;
        keyHash = _keyHash;
    }

    function requestRandomWords() external {
        COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            3,
            200000,
            1
        );
    }

    function fulfillRandomWords(uint256, uint256[] memory randomWords) internal override {
        randomNumber = randomWords[0];
    }
}

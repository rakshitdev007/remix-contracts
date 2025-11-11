// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract staking is Ownable, ReentrancyGuard {
    IERC20 public immutable token;

    // 3 years
    uint256 public stakeDuration = 3 * 365 days;

    // Reward percentage (scaled by 10000). 3000 = 30%
    uint256 public stkRwdPer = 3000;

    struct Stake {
        uint256 lastStakedtime;
        uint256 amount;
        uint256 duration;
        uint256 reward;
    }

    mapping(address => Stake) private stakeDetails;

    event Staked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);
    event Unstaked(address indexed user, uint256 amount);
    event StakeDurationUpdated(uint256 newDuration);
    event StakeRewardUpdated(uint256 newRewardRate);

    constructor(address _token, address initialOwner) Ownable(initialOwner) {
        token = IERC20(_token);
    }

    function stake(uint256 value) external nonReentrant {
        require(value > 0, "Amount should not be 0");
        _updateReward(msg.sender);

        require(
            token.transferFrom(msg.sender, address(this), value),
            "Token transfer failed"
        );

        Stake storage s = stakeDetails[msg.sender];
        s.amount += value;
        s.lastStakedtime = block.timestamp;
        s.duration = stakeDuration;

        emit Staked(msg.sender, value);
    }

    function _updateReward(address user) internal {
        Stake storage s = stakeDetails[user];
        if (s.amount == 0) return;

        uint256 timePassed = block.timestamp - s.lastStakedtime;
        uint256 pending = (s.amount * stkRwdPer * timePassed) /
            (s.duration * 10000);

        s.reward += pending;
        s.lastStakedtime = block.timestamp;
    }

    function claimReward() external nonReentrant {
        _updateReward(msg.sender);

        uint256 rewardAmount = stakeDetails[msg.sender].reward;
        require(rewardAmount > 0, "No rewards available");

        stakeDetails[msg.sender].reward = 0;
        require(
            token.transfer(msg.sender, rewardAmount),
            "Reward transfer failed"
        );

        emit RewardClaimed(msg.sender, rewardAmount);
    }

    function unstake(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be > 0");
        Stake storage s = stakeDetails[msg.sender];
        require(s.amount >= amount, "Not enough staked");

        _updateReward(msg.sender);

        s.amount -= amount;
        require(token.transfer(msg.sender, amount), "Unstake transfer failed");

        emit Unstaked(msg.sender, amount);
    }

    // Admin settings
    function setStakeDuration(uint256 _duration) external onlyOwner {
        stakeDuration = _duration;
        emit StakeDurationUpdated(_duration);
    }

    function setStakeReward(uint256 _stkRwdPer) external onlyOwner {
        stkRwdPer = _stkRwdPer;
        emit StakeRewardUpdated(_stkRwdPer);
    }
}

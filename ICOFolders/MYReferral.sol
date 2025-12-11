// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IReferral {
    error InvalidAddress();
    error AlreadyInitialize();
    error NotInitialize();
    error InsufficientRewardToken();

    event ReferralAdded(address indexed user, address indexed referrer);
    event ReferralReward(
        address indexed user,
        address indexed referrer,
        uint256 reward
    );
}

enum SaleTokenOption {
    TokenReceiveAfterSaleEnd,
    TokenReceiveImmediately
}

enum SaleType {
    Private,
    Public
}

struct ICO {
    SaleType saleType;
    uint256 startAt;
    uint256 endAt;
    uint256 totalTokens;
    SaleTokenOption saleTokenOption;
    address saleToken;
}

interface IICO {
    function saleType2IcoDetail(
        SaleType saleType_
    ) external view returns (ICO memory);
}

contract MYReferral is Ownable, ReentrancyGuard, IReferral {
    using SafeERC20 for IERC20;

    mapping(address => address) private _user2Referrer;
    mapping(address => address[]) private _referrals;
    mapping(address => uint256) private _referralRewards;
    mapping(address => mapping(SaleType => uint256)) private _pendingRewards;

    address public handler;

    bool public isInitialized;

    uint256 public totalReferralBonusReward;
    uint256 public totalReferralBonusAllocation;
    uint8 public rewardPercentage = 10;

    IERC20 public rewardToken;

    constructor() Ownable(msg.sender) {}

    function initialize(
        address rewardToken_,
        uint256 totalReferralBonusAllocation_,
        address initialHandler_
    ) external onlyOwner {
        if (isInitialized) revert AlreadyInitialize();
        if (
            rewardToken_ == address(0) ||
            initialHandler_ == address(0)
        ) revert InvalidAddress();

        rewardToken = IERC20(rewardToken_);
        handler = initialHandler_;

        isInitialized = true;

        rewardToken.safeTransferFrom(
            msg.sender,
            address(this),
            totalReferralBonusAllocation_
        );

        totalReferralBonusAllocation = totalReferralBonusAllocation_;
    }

    modifier onlyHandler() {
        require(msg.sender == handler, "Caller is not Handler");
        _;
    }

    function updateHandler(address handler_) external onlyOwner {
        handler = handler_;
    }

    function addReferral(address user_, address referrer_) external onlyHandler {
        if (!isInitialized) revert NotInitialize();

        if (_user2Referrer[user_] == address(0)) {
            _user2Referrer[user_] = referrer_;
            _referrals[referrer_].push(user_);
            emit ReferralAdded(user_, referrer_);
        }
    }

    function distributeRewards(
        address account_,
        uint256 tokenAmount_,
        SaleType saleType_
    ) external onlyHandler nonReentrant {
        address referrer_ = _user2Referrer[account_];
        uint256 rewardAmount = (tokenAmount_ * rewardPercentage) / 100;

        if (rewardAmount > totalReferralBonusAllocation)
            revert InsufficientRewardToken();

        if (saleType_ == SaleType.Public) {
            _pendingRewards[referrer_][saleType_] += rewardAmount;
        } else {
            _referralRewards[referrer_] += rewardAmount;
            rewardToken.safeTransfer(referrer_, rewardAmount);

            emit ReferralReward(account_, referrer_, rewardAmount);
        }

        totalReferralBonusAllocation -= rewardAmount;
        totalReferralBonusReward += rewardAmount;
    }

    function claimPendingRewards(SaleType saleType_) external nonReentrant {
        address referrer_ = msg.sender;

        uint256 reward = _pendingRewards[referrer_][saleType_];
        if (reward == 0) revert("NoPendingRewards");

        if (!hasSaleEnded(saleType_)) revert("SaleNotEndedYet");

        _pendingRewards[referrer_][saleType_] = 0;
        _referralRewards[referrer_] += reward;

        rewardToken.safeTransfer(referrer_, reward);

        emit ReferralReward(referrer_, referrer_, reward);
    }

    function hasSaleEnded(SaleType saleType_) public view returns (bool) {
        ICO memory detail = IICO(handler).saleType2IcoDetail(saleType_);
        return block.timestamp >= detail.endAt;
    }

    function getReferrer(address user_) public view returns (address) {
        return _user2Referrer[user_];
    }

    function getReferralsCount(
        address referrer_
    ) public view returns (uint256) {
        return _referrals[referrer_].length;
    }

    function getReferralRewards(
        address referrer_
    ) external view returns (uint256) {
        return _referralRewards[referrer_];
    }
}

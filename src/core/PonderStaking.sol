// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IERC20.sol";

contract PonderStaking {
    IERC20 public immutable ponder;
    IERC20 public immutable stablecoin;

    uint256 public totalStaked;
    uint256 public accRewardPerShare;  // Accumulated rewards per share, scaled by 1e18

    struct UserInfo {
        uint256 amount;         // How many PONDER tokens staked
        uint256 rewardDebt;     // Reward debt
        uint256 pendingRewards; // Unclaimed rewards in stablecoin
    }

    mapping(address => UserInfo) public userInfo;

    error InsufficientBalance();
    error NoRewards();
    error ZeroAmount();

    event Stake(address indexed user, uint256 amount);
    event Unstake(address indexed user, uint256 amount);
    event ClaimRewards(address indexed user, uint256 amount);
    event RewardsDistributed(uint256 amount);

    constructor(address _ponder, address _stablecoin) {
        ponder = IERC20(_ponder);
        stablecoin = IERC20(_stablecoin);
    }

    function stake(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        UserInfo storage user = userInfo[msg.sender];

        // Update rewards
        if (user.amount > 0) {
            uint256 pending = (user.amount * accRewardPerShare / 1e18) - user.rewardDebt;
            if (pending > 0) {
                user.pendingRewards += pending;
            }
        }

        // Transfer PONDER tokens
        ponder.transferFrom(msg.sender, address(this), amount);

        user.amount += amount;
        totalStaked += amount;
        user.rewardDebt = user.amount * accRewardPerShare / 1e18;

        emit Stake(msg.sender, amount);
    }

    function unstake(uint256 amount) external {
        UserInfo storage user = userInfo[msg.sender];
        if (amount == 0) revert ZeroAmount();
        if (user.amount < amount) revert InsufficientBalance();

        // Update rewards
        uint256 pending = (user.amount * accRewardPerShare / 1e18) - user.rewardDebt;
        if (pending > 0) {
            user.pendingRewards += pending;
        }

        user.amount -= amount;
        totalStaked -= amount;
        user.rewardDebt = user.amount * accRewardPerShare / 1e18;

        ponder.transfer(msg.sender, amount);

        emit Unstake(msg.sender, amount);
    }

    function claimRewards() external {
        UserInfo storage user = userInfo[msg.sender];

        // Calculate pending rewards
        uint256 pending = (user.amount * accRewardPerShare / 1e18) - user.rewardDebt;
        uint256 totalRewards = user.pendingRewards + pending;

        if (totalRewards == 0) revert NoRewards();

        // Reset rewards
        user.pendingRewards = 0;
        user.rewardDebt = user.amount * accRewardPerShare / 1e18;

        // Transfer rewards
        stablecoin.transfer(msg.sender, totalRewards);

        emit ClaimRewards(msg.sender, totalRewards);
    }

    // Called by pairs when distributing fees
    function distributeProtocolFees(uint256 amount) external {
        if (totalStaked == 0) return;

        // Transfer stablecoins from pair
        stablecoin.transferFrom(msg.sender, address(this), amount);

        // Update accumulated reward per share
        accRewardPerShare += (amount * 1e18) / totalStaked;

        emit RewardsDistributed(amount);
    }
}

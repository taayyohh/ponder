// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IPonderStaking {
    struct UserInfo {
        uint256 amount;         // How many PONDER tokens staked
        uint256 rewardDebt;     // Reward debt
        uint256 pendingRewards; // Unclaimed rewards in stablecoin
    }

    event Stake(address indexed user, uint256 amount);
    event Unstake(address indexed user, uint256 amount);
    event ClaimRewards(address indexed user, uint256 amount);
    event RewardsDistributed(uint256 amount);

    function ponder() external view returns (address);
    function stablecoin() external view returns (address);
    function totalStaked() external view returns (uint256);
    function accRewardPerShare() external view returns (uint256);
    function userInfo(address user) external view returns (UserInfo memory);

    function stake(uint256 amount) external;
    function unstake(uint256 amount) external;
    function claimRewards() external;
    function distributeProtocolFees(uint256 amount) external;
}

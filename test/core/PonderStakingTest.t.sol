// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/core/PonderStaking.sol";
import "../mocks/ERC20Mint.sol";

contract PonderStakingTest is Test {
    PonderStaking staking;
    ERC20Mint ponder;
    ERC20Mint stablecoin;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address pair = makeAddr("pair");

    event Stake(address indexed user, uint256 amount);
    event Unstake(address indexed user, uint256 amount);
    event RewardsDistributed(uint256 amount);
    event ClaimRewards(address indexed user, uint256 amount);

    function setUp() public {
        // Deploy tokens
        ponder = new ERC20Mint("PONDER", "PONDER");
        stablecoin = new ERC20Mint("USDT", "USDT");

        // Deploy staking contract
        staking = new PonderStaking(address(ponder), address(stablecoin));

        // Setup initial balances
        ponder.mint(alice, 1000e18);
        ponder.mint(bob, 1000e18);
        stablecoin.mint(pair, 1000e18);

        // Approvals for pair
        vm.prank(pair);
        stablecoin.approve(address(staking), type(uint256).max);
    }

    function testInitialization() public {
        assertEq(address(staking.ponder()), address(ponder));
        assertEq(address(staking.stablecoin()), address(stablecoin));
        assertEq(staking.totalStaked(), 0);
        assertEq(staking.accRewardPerShare(), 0);
    }

    function testStake() public {
        vm.startPrank(alice);
        ponder.approve(address(staking), 100e18);

        vm.expectEmit(true, false, false, true);
        emit Stake(alice, 100e18);
        staking.stake(100e18);

        (uint256 amount, uint256 rewardDebt, uint256 pendingRewards) = staking.userInfo(alice);
        assertEq(amount, 100e18);
        assertEq(staking.totalStaked(), 100e18);
        assertEq(ponder.balanceOf(address(staking)), 100e18);
        vm.stopPrank();
    }

    function testFailStakeZeroAmount() public {
        vm.prank(alice);
        staking.stake(0);
    }

    function testFailStakeWithoutApproval() public {
        vm.prank(alice);
        staking.stake(100e18);
    }

    function testUnstake() public {
        // Setup initial stake
        vm.startPrank(alice);
        ponder.approve(address(staking), 100e18);
        staking.stake(100e18);

        // Unstake half
        vm.expectEmit(true, false, false, true);
        emit Unstake(alice, 50e18);
        staking.unstake(50e18);

        (uint256 amount, uint256 rewardDebt, uint256 pendingRewards) = staking.userInfo(alice);
        assertEq(amount, 50e18);
        assertEq(staking.totalStaked(), 50e18);
        assertEq(ponder.balanceOf(alice), 950e18);
        vm.stopPrank();
    }

    function testFailUnstakeZeroAmount() public {
        vm.prank(alice);
        staking.unstake(0);
    }

    function testFailUnstakeMoreThanStaked() public {
        vm.startPrank(alice);
        ponder.approve(address(staking), 100e18);
        staking.stake(100e18);
        staking.unstake(200e18);
        vm.stopPrank();
    }

    function testRewardDistribution() public {
        // Setup two equal stakes
        vm.startPrank(alice);
        ponder.approve(address(staking), 100e18);
        staking.stake(100e18);
        vm.stopPrank();

        vm.startPrank(bob);
        ponder.approve(address(staking), 100e18);
        staking.stake(100e18);
        vm.stopPrank();

        // Distribute rewards
        vm.prank(pair);
        vm.expectEmit(true, false, false, true);
        emit RewardsDistributed(100e18);
        staking.distributeProtocolFees(100e18);

        // Check reward calculations
        (,, uint256 alicePendingRewards) = staking.userInfo(alice);
        (,, uint256 bobPendingRewards) = staking.userInfo(bob);

        assertEq(alicePendingRewards + bobPendingRewards, 100e18);
        assertEq(alicePendingRewards, 50e18); // Equal stakes should get equal rewards
        assertEq(bobPendingRewards, 50e18);
    }

    function testClaimRewards() public {
        // Setup stake
        vm.startPrank(alice);
        ponder.approve(address(staking), 100e18);
        staking.stake(100e18);
        vm.stopPrank();

        // Distribute rewards
        vm.prank(pair);
        staking.distributeProtocolFees(100e18);

        // Claim rewards
        uint256 balanceBefore = stablecoin.balanceOf(alice);

        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit ClaimRewards(alice, 100e18);
        staking.claimRewards();

        assertEq(stablecoin.balanceOf(alice) - balanceBefore, 100e18);
        (,, uint256 pendingRewards) = staking.userInfo(alice);
        assertEq(pendingRewards, 0);
    }

    function testFailClaimWithNoRewards() public {
        vm.prank(alice);
        staking.claimRewards();
    }

    function testAccumulatingRewards() public {
        // Setup stake
        vm.startPrank(alice);
        ponder.approve(address(staking), 100e18);
        staking.stake(100e18);
        vm.stopPrank();

        // Multiple reward distributions
        vm.startPrank(pair);
        staking.distributeProtocolFees(50e18);
        staking.distributeProtocolFees(50e18);
        vm.stopPrank();

        // Claim accumulated rewards
        vm.prank(alice);
        staking.claimRewards();

        assertEq(stablecoin.balanceOf(alice), 100e18);
    }

    function testRewardsAfterUnstake() public {
        // Setup stake
        vm.startPrank(alice);
        ponder.approve(address(staking), 100e18);
        staking.stake(100e18);

        // First reward distribution
        vm.prank(pair);
        staking.distributeProtocolFees(100e18);

        // Unstake half
        staking.unstake(50e18);

        // Second reward distribution
        vm.prank(pair);
        staking.distributeProtocolFees(100e18);

        // Claim all rewards
        staking.claimRewards();
        vm.stopPrank();

        // First distribution: 100e18 (full share)
        // Second distribution: 50e18 (half share)
        assertEq(stablecoin.balanceOf(alice), 150e18);
    }

    function testEmergencyWithdraw() public {
        // Setup stake
        vm.startPrank(alice);
        ponder.approve(address(staking), 100e18);
        staking.stake(100e18);
        vm.stopPrank();

        // Distribute rewards
        vm.prank(pair);
        staking.distributeProtocolFees(100e18);

        // Emergency withdraw
        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit Unstake(alice, 100e18);
        staking.unstake(100e18);

        assertEq(ponder.balanceOf(alice), 1000e18);
        assertEq(staking.totalStaked(), 0);
    }
}

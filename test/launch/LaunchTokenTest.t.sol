// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/launch/LaunchToken.sol";

contract LaunchTokenTest is Test {
    LaunchToken token;
    address creator = address(0x1);
    address launcher = address(0x2);
    address user1 = address(0x3);
    address user2 = address(0x4);
    address pair = address(0x5);

    // Test constants
    uint256 constant TOTAL_SUPPLY = 555_555_555 ether;
    uint256 constant VESTING_DURATION = 180 days;
    uint256 constant CREATOR_SWAP_FEE = 10; // 0.1%
    uint256 constant FEE_DENOMINATOR = 10000;

    event VestingInitialized(address indexed creator, uint256 amount, uint256 startTime, uint256 endTime);
    event TokensClaimed(address indexed creator, uint256 amount);
    event CreatorFeePaid(address indexed creator, uint256 amount);
    event TransfersEnabled();

    function setUp() public {
        // Deploy and initialize token
        token = new LaunchToken();
        vm.startPrank(launcher);
        token.initialize("Test Token", "TEST", TOTAL_SUPPLY, launcher);
        vm.stopPrank();

        // Label addresses for better test traces
        vm.label(creator, "Creator");
        vm.label(launcher, "Launcher");
        vm.label(user1, "User1");
        vm.label(user2, "User2");
        vm.label(pair, "LP Pair");
    }

    // Basic Functionality Tests
    function testInitialization() public {
        assertEq(token.name(), "Test Token");
        assertEq(token.symbol(), "TEST");
        assertEq(token.totalSupply(), TOTAL_SUPPLY);
        assertEq(token.balanceOf(launcher), TOTAL_SUPPLY);
        assertTrue(!token.transfersEnabled());
    }

    function testFailDoubleInitialize() public {
        vm.prank(launcher);
        token.initialize("Test2", "TEST2", TOTAL_SUPPLY, launcher);
    }

    function testTransferRestrictions() public {
        // Transfers should be disabled initially
        vm.prank(launcher);
        token.transfer(user1, 1000);

        vm.prank(user1);
        vm.expectRevert(LaunchToken.TransfersDisabled.selector);
        token.transfer(user2, 100);

        // Enable transfers
        vm.prank(launcher);
        token.enableTransfers();

        // Now transfers should work
        vm.prank(user1);
        token.transfer(user2, 100);
        assertEq(token.balanceOf(user2), 100);
    }

    // Vesting Tests
    function testVestingSetup() public {
        uint256 vestingAmount = TOTAL_SUPPLY / 10;

        vm.prank(launcher);
        vm.expectEmit(true, true, false, true);
        emit VestingInitialized(creator, vestingAmount, block.timestamp, block.timestamp + VESTING_DURATION);
        token.setupVesting(creator, vestingAmount);

        (
            uint256 total,
            uint256 claimed,
            uint256 available,
            uint256 start,
            uint256 end
        ) = token.getVestingInfo();

        assertEq(total, vestingAmount);
        assertEq(claimed, 0);
        assertEq(start, block.timestamp);
        assertEq(end, block.timestamp + VESTING_DURATION);
        assertGt(available, 0);
    }

    function testLinearVesting() public {
        uint256 vestingAmount = TOTAL_SUPPLY / 10;

        vm.prank(launcher);
        token.setupVesting(creator, vestingAmount);

        // Test at different vesting milestones
        uint256[] memory checkpoints = new uint256[](4);
        checkpoints[0] = 45 days;   // 25%
        checkpoints[1] = 90 days;   // 50%
        checkpoints[2] = 135 days;  // 75%
        checkpoints[3] = 180 days;  // 100%

        uint256 totalClaimed = 0;
        for (uint256 i = 0; i < checkpoints.length; i++) {
            vm.warp(block.timestamp + checkpoints[i]);

            vm.prank(creator);
            token.claimVestedTokens();

            uint256 expectedVested = (vestingAmount * (i + 1)) / 4;
            totalClaimed += token.balanceOf(creator) - totalClaimed;

            assertApproxEqRel(
                totalClaimed,
                expectedVested,
                0.01e18
            );
        }
    }

    // Swap Fee Tests
    function testCreatorFeeOnSwaps() public {
        setUpForSwapTests();

        uint256 swapAmount = 1000e18;
        uint256 expectedFee = (swapAmount * CREATOR_SWAP_FEE) / FEE_DENOMINATOR;

        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit CreatorFeePaid(creator, expectedFee);
        token.transfer(pair, swapAmount);

        assertEq(token.balanceOf(creator), expectedFee);
        assertEq(token.balanceOf(pair), swapAmount - expectedFee);
    }

    function testComplexSwapScenarios() public {
        setUpForSwapTests();
        uint256 swapAmount = 1000e18;

        // Multiple swaps in sequence
        for(uint256 i = 0; i < 5; i++) {
            vm.prank(user1);
            token.transfer(pair, swapAmount);

            vm.prank(pair);
            token.transfer(user2, swapAmount - (swapAmount * CREATOR_SWAP_FEE) / FEE_DENOMINATOR);
        }

        // Verify cumulative fees
        uint256 expectedTotalFee = (swapAmount * CREATOR_SWAP_FEE * 5) / FEE_DENOMINATOR;
        assertApproxEqRel(token.balanceOf(creator), expectedTotalFee, 0.01e18);
    }

    function testFeeRoundingEdgeCases() public {
        setUpForSwapTests();

        // Test very small amounts
        uint256 smallAmount = 100; // Small enough to test rounding

        vm.prank(user1);
        token.transfer(pair, smallAmount);

        // Even with tiny amounts, creator should get something if fee applies
        assertTrue(token.balanceOf(creator) > 0);

        // Test very large amounts
        uint256 largeAmount = TOTAL_SUPPLY / 2;
        vm.prank(launcher);
        token.transfer(user1, largeAmount);

        vm.prank(user1);
        token.transfer(pair, largeAmount);

        uint256 expectedLargeFee = (largeAmount * CREATOR_SWAP_FEE) / FEE_DENOMINATOR;
        assertApproxEqRel(token.balanceOf(creator), expectedLargeFee, 0.01e18);
    }

    // Helper Functions
    function setUpForSwapTests() internal {
        // Setup vesting
        vm.startPrank(launcher);
        token.setupVesting(creator, TOTAL_SUPPLY / 10);

        // Enable transfers
        token.enableTransfers();

        // Distribute tokens for testing
        token.transfer(user1, TOTAL_SUPPLY / 4);
        token.transfer(user2, TOTAL_SUPPLY / 4);
        vm.stopPrank();
    }

    function testFailUnauthorizedVestingSetup() public {
        vm.prank(user1); // Not launcher
        vm.expectRevert(LaunchToken.Unauthorized.selector);
        token.setupVesting(creator, TOTAL_SUPPLY / 10);
    }

    function testFailDoubleVestingSetup() public {
        vm.startPrank(launcher);
        token.setupVesting(creator, TOTAL_SUPPLY / 10);
        vm.expectRevert(); // Should fail on second setup
        token.setupVesting(creator, TOTAL_SUPPLY / 10);
        vm.stopPrank();
    }

    function testNonLPTransferNoFee() public {
        setUpForSwapTests();
        uint256 amount = 1000e18;

        // Initial creator balance
        uint256 creatorBalanceBefore = token.balanceOf(creator);

        // Transfer between regular users should not incur fee
        vm.prank(user1);
        token.transfer(user2, amount);

        assertEq(token.balanceOf(user2), amount, "Full amount should transfer");
        assertEq(token.balanceOf(creator), creatorBalanceBefore, "No fee should be charged");
    }

    function testFailInsufficientBalanceTransfer() public {
        setUpForSwapTests();
        uint256 balance = token.balanceOf(user1);

        vm.prank(user1);
        token.transfer(user2, balance + 1); // Try to transfer more than balance
    }

    function testClaimVestedTokensAfterCompletion() public {
        uint256 vestingAmount = TOTAL_SUPPLY / 10;

        vm.prank(launcher);
        token.setupVesting(creator, vestingAmount);

        // Move past vesting end
        vm.warp(block.timestamp + VESTING_DURATION + 1 days);

        vm.prank(creator);
        token.claimVestedTokens();

        // Try to claim again
        vm.prank(creator);
        vm.expectRevert(LaunchToken.NoTokensAvailable.selector);
        token.claimVestedTokens();
    }

    function testPartialVestingClaims() public {
        uint256 vestingAmount = TOTAL_SUPPLY / 10;
        vm.prank(launcher);
        token.setupVesting(creator, vestingAmount);

        // Move to 25% vested
        vm.warp(block.timestamp + 45 days);

        // First claim
        vm.prank(creator);
        token.claimVestedTokens();
        uint256 firstClaim = token.balanceOf(creator);

        // Move to 50% vested
        vm.warp(block.timestamp + 45 days);

        // Second claim
        vm.prank(creator);
        token.claimVestedTokens();
        uint256 secondClaim = token.balanceOf(creator) - firstClaim;

        // Claims should be approximately equal
        assertApproxEqRel(firstClaim, secondClaim, 0.01e18);
    }

    receive() external payable {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../src/core/PonderERC20.sol";
import "../../src/core/PonderFactory.sol";
import "../../src/launch/FiveFiveFiveLauncher.sol";
import "../../src/launch/LaunchToken.sol";
import "../../src/periphery/PonderRouter.sol";
import "../../test/mocks/WETH9.sol";
import "../mocks/MockKKUBUnwrapper.sol";
import "forge-std/Test.sol";

contract LaunchSystemTest is Test {
    FiveFiveFiveLauncher launcher;
    PonderFactory factory;
    PonderRouter router;
    WETH9 weth;

    address creator = makeAddr("creator");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address feeCollector = makeAddr("feeCollector");

    uint256 constant TARGET_RAISE = 5555 ether;
    uint256 constant TOTAL_SUPPLY = 555_555_555 ether;

    event LaunchCreated(uint256 indexed launchId, address indexed token, address creator, string imageURI);
    event Contributed(uint256 indexed launchId, address indexed contributor, uint256 amount);
    event TokenPurchased(uint256 indexed launchId, address indexed buyer, uint256 ethAmount, uint256 tokenAmount);
    event CreatorFeePaid(uint256 indexed launchId, address indexed creator, uint256 feeAmount);
    event ProtocolFeePaid(uint256 indexed launchId, uint256 feeAmount);
    event LaunchCompleted(uint256 indexed launchId, uint256 totalRaised, uint256 tokensSold);

    function setUp() public {
        // Deploy core contracts
        weth = new WETH9();
        factory = new PonderFactory(address(this), address(1)); // Pass launcher address
        MockKKUBUnwrapper unwrapper = new MockKKUBUnwrapper(address(weth));
        router = new PonderRouter(address(factory), address(weth), address(unwrapper));

        // Deploy launcher
        launcher = new FiveFiveFiveLauncher(
            address(factory),
            payable(address(router)),
            feeCollector
        );

        // Fund accounts
        vm.deal(creator, 10000 ether);
        vm.deal(user1, 10000 ether);
        vm.deal(user2, 10000 ether);
    }

    function testCreateLaunch() public {
        vm.startPrank(creator);
        uint256 launchId = launcher.createLaunch(
            "TestToken",
            "TEST",
            "ipfs://test"
        );

        (
            address tokenAddress,
            string memory name,
            string memory symbol,
            string memory imageURI,
            uint256 totalRaised,
            bool launched,
            uint256 lpUnlockTime
        ) = launcher.getLaunchInfo(launchId);

        assertEq(name, "TestToken");
        assertEq(symbol, "TEST");
        assertEq(imageURI, "ipfs://test");
        assertEq(totalRaised, 0);
        assertFalse(launched);
        assertEq(lpUnlockTime, 0);
        assertTrue(tokenAddress != address(0));

        vm.stopPrank();
    }

    function testContribute() public {
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch(
            "TestToken",
            "TEST",
            "ipfs://test"
        );

        (address tokenAddress,,,,,, ) = launcher.getLaunchInfo(launchId);
        LaunchToken token = LaunchToken(tokenAddress);

        uint256 contribution = 1 ether;
        uint256 expectedTokens = getTokenAmount(contribution);

        vm.startPrank(user1);
        uint256 balanceBefore = token.balanceOf(user1);

        launcher.contribute{value: contribution}(launchId);

        assertEq(
            token.balanceOf(user1) - balanceBefore,
            expectedTokens,
            "Incorrect token amount received"
        );
        vm.stopPrank();
    }

    function testCompleteLaunch() public {
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch(
            "TestToken",
            "TEST",
            "ipfs://test"
        );

        // Split the contribution into smaller amounts
        uint256 splitAmount = TARGET_RAISE / 10;

        vm.startPrank(user1);
        for(uint i = 0; i < 9; i++) {
            launcher.contribute{value: splitAmount}(launchId);
        }
        launcher.contribute{value: TARGET_RAISE - (splitAmount * 9)}(launchId);
        vm.stopPrank();

        (,,,, uint256 totalRaised, bool launched,) = launcher.getLaunchInfo(launchId);
        assertTrue(launched, "Launch not completed");
        assertEq(totalRaised, TARGET_RAISE, "Incorrect total raised");
    }

    function testVesting() public {
        // Create launch
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch(
            "TestToken",
            "TEST",
            "ipfs://test"
        );

        // Complete launch with multiple contributions
        uint256 splitAmount = TARGET_RAISE / 10;

        vm.startPrank(user1);
        for(uint i = 0; i < 9; i++) {
            launcher.contribute{value: splitAmount}(launchId);
        }
        launcher.contribute{value: TARGET_RAISE - (splitAmount * 9)}(launchId);
        vm.stopPrank();

        // Get token
        (address tokenAddress,,,,,, ) = launcher.getLaunchInfo(launchId);
        LaunchToken token = LaunchToken(tokenAddress);

        // Test vesting claims
        vm.startPrank(creator);

        // Move halfway through vesting
        vm.warp(block.timestamp + 90 days);

        uint256 balanceBefore = token.balanceOf(creator);
        token.claimVestedTokens();

        assertGt(
            token.balanceOf(creator),
            balanceBefore,
            "No tokens claimed"
        );

        vm.stopPrank();
    }

    function testLPLocking() public {
        // Create launch
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch(
            "TestToken",
            "TEST",
            "ipfs://test"
        );

        // Complete launch with full amount in one go
        vm.startPrank(user1);
        launcher.contribute{value: TARGET_RAISE}(launchId);
        vm.stopPrank();

        // This automatically sets up initial liquidity
        // The launch completion adds liquidity using the protocol's preset ratios

        // Try to withdraw LP too early - should fail
        vm.startPrank(creator);
        vm.expectRevert(FiveFiveFiveLauncher.LPStillLocked.selector);
        launcher.withdrawLP(launchId);
        vm.stopPrank();

        // Move past lock period
        vm.warp(block.timestamp + 180 days + 1);

        // Should succeed now
        vm.startPrank(creator);
        launcher.withdrawLP(launchId);

        // Get pair address and verify LP tokens received
        (address tokenAddress,,,,,, ) = launcher.getLaunchInfo(launchId);
        address pair = factory.getPair(tokenAddress, address(weth));
        assertGt(PonderERC20(pair).balanceOf(creator), 0, "No LP tokens received");
        vm.stopPrank();
    }

    function testTradingFees() public {
        // Create and fully fund launch
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch("TestToken", "TEST", "ipfs://test");

        vm.startPrank(user1);
        launcher.contribute{value: TARGET_RAISE}(launchId);
        vm.stopPrank();

        // Get launch token info
        (address tokenAddress,,,,,, ) = launcher.getLaunchInfo(launchId);
        LaunchToken token = LaunchToken(tokenAddress);
        address pair = factory.getPair(tokenAddress, address(weth));

        // Log initial state
        (uint112 reserve0, uint112 reserve1,) = PonderPair(pair).getReserves();
        console.log("Initial reserves:");
        console.log("Reserve0:", reserve0);
        console.log("Reserve1:", reserve1);

        // Use a very tiny swap amount - just 0.0001% of total supply
        uint256 swapAmount = TOTAL_SUPPLY / 1_000_000;
        console.log("Swap amount:", swapAmount);

        vm.startPrank(user1);

        // First ensure we have approval
        token.approve(address(router), swapAmount);

        // Verify balance is sufficient
        uint256 balance = token.balanceOf(user1);
        console.log("User balance:", balance);

        // Create path
        address[] memory path = new address[](2);
        path[0] = tokenAddress;
        path[1] = address(weth);

        // Calculate amounts with router
        uint256[] memory amounts = router.getAmountsOut(swapAmount, path);
        console.log("Amount in:", amounts[0]);
        console.log("Amount out:", amounts[1]);

        // Calculate K before swap
        uint256 kBefore = uint256(reserve0) * uint256(reserve1);
        console.log("K before:", kBefore);

        // Try the swap with no minimum output
        router.swapExactTokensForETH(
            swapAmount,
            0, // Accept any output amount
            path,
            user1,
            block.timestamp + 600 // 10 minute deadline
        );

        vm.stopPrank();

        // Log final state
        (uint112 reserveAfter0, uint112 reserveAfter1,) = PonderPair(pair).getReserves();
        uint256 kAfter = uint256(reserveAfter0) * uint256(reserveAfter1);
        console.log("Final reserves:");
        console.log("Reserve0:", reserveAfter0);
        console.log("Reserve1:", reserveAfter1);
        console.log("K after:", kAfter);
    }

    function getTokenAmount(uint256 ethAmount) internal pure returns (uint256) {
        uint256 totalTokensForSale = (TOTAL_SUPPLY * 80) / 100; // 80% of supply
        return (ethAmount * totalTokensForSale) / TARGET_RAISE;
    }

    receive() external payable {}
}

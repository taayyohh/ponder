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

//    function testLPLocking() public {
//        // Create launch
//        vm.prank(creator);
//        uint256 launchId = launcher.createLaunch(
//            "TestToken",
//            "TEST",
//            "ipfs://test"
//        );
//
//        // Complete launch with multiple contributions
//        uint256 splitAmount = TARGET_RAISE / 10;
//
//        vm.startPrank(user1);
//        for(uint i = 0; i < 9; i++) {
//            launcher.contribute{value: splitAmount}(launchId);
//        }
//        launcher.contribute{value: TARGET_RAISE - (splitAmount * 9)}(launchId);
//        vm.stopPrank();
//
//        // Add liquidity to the pool
//        vm.startPrank(creator);
//        (address tokenAddress,,,,,, ) = launcher.getLaunchInfo(launchId);
//        LaunchToken token = LaunchToken(tokenAddress);
//        uint256 tokenAmountDesired = TOTAL_SUPPLY / 2;
//        uint256 liquidityAmount = 50 ether; // Reduced liquidity amount to match ratio better
//        token.approve(address(router), tokenAmountDesired);
//        router.addLiquidityETH{value: liquidityAmount}(
//            tokenAddress,
//            tokenAmountDesired,
//            tokenAmountDesired / 2,
//            liquidityAmount / 2,
//            creator,
//            block.timestamp + 60
//        );
//        vm.stopPrank();
//
//        // Try to withdraw LP too early
//        vm.startPrank(creator);
//        vm.expectRevert(FiveFiveFiveLauncher.LPStillLocked.selector);
//        launcher.withdrawLP(launchId);
//        vm.stopPrank();
//
//        // Move past lock period
//        vm.warp(block.timestamp + 180 days + 1);
//
//        // Withdraw LP
//        vm.startPrank(creator);
//        launcher.withdrawLP(launchId);
//
//        // Verify LP tokens received
//        address pair = factory.getPair(tokenAddress, address(weth));
//        assertGt(PonderERC20(pair).balanceOf(creator), 0, "No LP tokens received");
//        vm.stopPrank();
//    }
//
//    function testTradingFees() public {
//        // Create and complete launch
//        vm.prank(creator);
//        uint256 launchId = launcher.createLaunch("TestToken", "TEST", "ipfs://test");
//
//        // Complete launch with multiple contributions
//        uint256 splitAmount = TARGET_RAISE / 10;
//        vm.startPrank(user1);
//        for (uint i = 0; i < 5; i++) {
//            launcher.contribute{value: splitAmount}(launchId);
//        }
//        vm.stopPrank();
//
//        vm.startPrank(user2);
//        for (uint i = 0; i < 4; i++) {
//            launcher.contribute{value: splitAmount}(launchId);
//        }
//        launcher.contribute{value: TARGET_RAISE - (splitAmount * 9)}(launchId);
//        vm.stopPrank();
//
//        (address tokenAddress,,,,,, ) = launcher.getLaunchInfo(launchId);
//        LaunchToken token = LaunchToken(tokenAddress);
//
//        // Add liquidity to the pool
//        vm.startPrank(creator);
//        uint256 tokenAmountDesired = token.balanceOf(creator) / 2;
//        uint256 liquidityAmount = 50 ether; // Reduced liquidity amount to match ratio better
//        token.approve(address(router), tokenAmountDesired);
//        router.addLiquidityETH{value: liquidityAmount}(
//            tokenAddress,
//            tokenAmountDesired,
//            tokenAmountDesired / 2,
//            liquidityAmount / 2,
//            creator,
//            block.timestamp + 60
//        );
//        vm.stopPrank();
//
//        // Record creator's initial balance
//        uint256 creatorTokensBefore = token.balanceOf(creator);
//
//        // Perform swap with a sufficient amount
//        vm.startPrank(user1);
//        uint256 balance = token.balanceOf(user1);
//        uint256 tradeAmount = balance / 50; // Increased trade amount
//        token.approve(address(router), tradeAmount);
//
//        address[] memory path = new address[](2);
//        path[0] = tokenAddress;
//        path[1] = address(weth);
//
//        // Get amounts out
//        uint256[] memory amounts = router.getAmountsOut(tradeAmount, path);
//        uint256 minOut = amounts[1] * 90 / 100; // Reduced slippage tolerance to 10%
//
//        // Do the swap
//        router.swapExactTokensForETH(
//            tradeAmount,
//            minOut,
//            path,
//            user1,
//            block.timestamp + 60
//        );
//        vm.stopPrank();
//
//        // Verify creator received fees
//        assertGt(token.balanceOf(creator), creatorTokensBefore, "No trading fees received");
//    }

    function getTokenAmount(uint256 ethAmount) internal pure returns (uint256) {
        uint256 totalTokensForSale = (TOTAL_SUPPLY * 80) / 100; // 80% of supply
        return (ethAmount * totalTokensForSale) / TARGET_RAISE;
    }

    receive() external payable {}
}

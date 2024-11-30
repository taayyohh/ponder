// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/launch/FiveFiveFiveLauncher.sol";
import "../../src/core/PonderFactory.sol";
import "../../src/periphery/PonderRouter.sol";
import "../../src/launch/LaunchToken.sol";
import "../mocks/WETH9.sol";

contract FiveFiveFiveLauncherTest is Test {
    FiveFiveFiveLauncher launcher;
    PonderFactory factory;
    PonderRouter router;
    WETH9 weth;

    address creator = makeAddr("creator");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address feeCollector = makeAddr("feeCollector");

    uint256 constant TARGET_RAISE = 5555 ether;
    uint256 constant CREATOR_FEE = 255; // 2.55%
    uint256 constant PROTOCOL_FEE = 55; // 0.55%
    uint256 constant TOTAL_SUPPLY = 555_555_555 ether;

    event LaunchCreated(uint256 indexed launchId, address indexed token, address creator, string imageURI);
    event TokenPurchased(uint256 indexed launchId, address indexed buyer, uint256 kubAmount, uint256 tokenAmount);
    event LaunchCompleted(uint256 indexed launchId, uint256 totalRaised, uint256 totalSold);
    event CreatorFeePaid(uint256 indexed launchId, address indexed creator, uint256 amount);
    event ProtocolFeePaid(uint256 indexed launchId, uint256 amount);

    function setUp() public {
        // Deploy core contracts
        weth = new WETH9();
        factory = new PonderFactory(address(this));
        router = new PonderRouter(address(factory), address(weth), feeCollector);

        launcher = new FiveFiveFiveLauncher(
            address(factory),
            payable(address(router)),
            feeCollector
        );

        // Fund test accounts
        vm.deal(creator, 10000 ether);
        vm.deal(user1, 10000 ether);
        vm.deal(user2, 10000 ether);
    }

    function testCreateLaunch() public {
        vm.startPrank(creator);

        vm.expectEmit(true, true, true, true);
        emit LaunchCreated(0, address(0), creator, "ipfs://test");

        uint256 launchId = launcher.createLaunch(
            "Test Token",
            "TEST",
            "ipfs://test"
        );

        (
            address tokenAddress,
            string memory name,
            string memory symbol,
            ,,,
        ) = launcher.getLaunchInfo(launchId);

        assertEq(name, "Test Token");
        assertEq(symbol, "TEST");
        assertTrue(tokenAddress != address(0));

        LaunchToken token = LaunchToken(tokenAddress);
        assertEq(token.balanceOf(address(launcher)), TOTAL_SUPPLY);
        vm.stopPrank();
    }

    function testTokenPurchase() public {
        // Create launch
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch("Test", "TEST", "ipfs://test");

        (address tokenAddress,,,,,, ) = launcher.getLaunchInfo(launchId);
        LaunchToken token = LaunchToken(tokenAddress);

        // Get token price
        (uint256 tokenPrice, uint256 tokensForSale,,,,) = launcher.getSaleInfo(launchId);

        // Purchase tokens
        uint256 purchaseAmount = 100 ether;
        uint256 expectedTokens = (purchaseAmount * 1e18) / tokenPrice;

        vm.startPrank(user1);
        vm.expectEmit(true, true, false, true);
        emit TokenPurchased(launchId, user1, purchaseAmount, expectedTokens);

        launcher.contribute{value: purchaseAmount}(launchId);
        vm.stopPrank();

        assertEq(token.balanceOf(user1), expectedTokens);
    }

    function testLaunchCompletion() public {
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch("Test", "TEST", "ipfs://test");

        (address tokenAddress,,,,,, ) = launcher.getLaunchInfo(launchId);

        uint256 initialCreatorBalance = creator.balance;
        uint256 initialFeeCollectorBalance = feeCollector.balance;

        // Complete the raise
        vm.prank(user1);
        launcher.contribute{value: TARGET_RAISE}(launchId);

        // Verify launch completed
        (,,,,, bool launched,) = launcher.getLaunchInfo(launchId);
        assertTrue(launched);

        // Verify LP tokens created
        address pair = factory.getPair(tokenAddress, address(weth));
        assertTrue(pair != address(0));
        assertTrue(IERC20(pair).balanceOf(address(launcher)) > 0);

        // Verify fees distributed
        uint256 creatorFeeAmount = (TARGET_RAISE * CREATOR_FEE) / 10000;
        uint256 protocolFeeAmount = (TARGET_RAISE * PROTOCOL_FEE) / 10000;

        assertEq(
            creator.balance - initialCreatorBalance,
            creatorFeeAmount,
            "Creator fee incorrect"
        );

        assertEq(
            feeCollector.balance - initialFeeCollectorBalance,
            protocolFeeAmount,
            "Protocol fee incorrect"
        );
    }

    function testVestingAndLPLock() public {
        // Create and complete launch
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch("Test", "TEST", "ipfs://test");

        vm.prank(user1);
        launcher.contribute{value: TARGET_RAISE}(launchId);

        (address tokenAddress,,,,,, ) = launcher.getLaunchInfo(launchId);
        LaunchToken token = LaunchToken(tokenAddress);
        address pair = factory.getPair(tokenAddress, address(weth));

        // Try to withdraw LP too early
        vm.expectRevert(FiveFiveFiveLauncher.LPStillLocked.selector);
        vm.prank(creator);
        launcher.withdrawLP(launchId);

        // Move past lock period
        vm.warp(block.timestamp + 180 days);

        // Should be able to withdraw LP now
        vm.prank(creator);
        launcher.withdrawLP(launchId);

        assertEq(IERC20(pair).balanceOf(address(launcher)), 0);
        assertTrue(IERC20(pair).balanceOf(creator) > 0);

        // Verify creator can claim vested tokens
        uint256 vestedBalance = token.balanceOf(creator);
        vm.prank(creator);
        token.claimVestedTokens();
        assertTrue(token.balanceOf(creator) > vestedBalance);
    }

    function testMultipleContributors() public {
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch("Test", "TEST", "ipfs://test");

        (address tokenAddress,,,,,, ) = launcher.getLaunchInfo(launchId);
        LaunchToken token = LaunchToken(tokenAddress);

        // Multiple users contribute
        vm.prank(user1);
        launcher.contribute{value: 2000 ether}(launchId);

        vm.prank(user2);
        launcher.contribute{value: 3555 ether}(launchId);

        // Verify both received tokens
        assertTrue(token.balanceOf(user1) > 0);
        assertTrue(token.balanceOf(user2) > 0);

        // Verify launch completed
        (,,,,, bool launched,) = launcher.getLaunchInfo(launchId);
        assertTrue(launched);
    }

    function testTokenPriceCalculation() public {
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch("Test", "TEST", "ipfs://test");

        (uint256 tokenPrice, uint256 tokensForSale,,,,) = launcher.getSaleInfo(launchId);

        // Verify token price calculation
        uint256 expectedTokensForSale = (TOTAL_SUPPLY * 80) / 100; // 80% for sale
        assertEq(tokensForSale, expectedTokensForSale, "Incorrect tokens for sale");

        // Price should be TARGET_RAISE / tokensForSale
        uint256 expectedPrice = (TARGET_RAISE * 1e18) / tokensForSale;
        assertEq(tokenPrice, expectedPrice, "Incorrect token price");

        // Verify price by making a purchase
        uint256 purchaseAmount = 1000 ether;
        uint256 expectedTokens = (purchaseAmount * 1e18) / tokenPrice;

        vm.prank(user1);
        launcher.contribute{value: purchaseAmount}(launchId);

        (address tokenAddress,,,,,, ) = launcher.getLaunchInfo(launchId);
        LaunchToken token = LaunchToken(tokenAddress);
        assertEq(token.balanceOf(user1), expectedTokens, "Incorrect tokens received");
    }

    function testFailInvalidLaunch() public {
        vm.startPrank(creator);
        launcher.createLaunch("", "TEST", "ipfs://test"); // Empty name
    }

    function testFailLaunchAlreadyCompleted() public {
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch("Test", "TEST", "ipfs://test");

        vm.prank(user1);
        launcher.contribute{value: TARGET_RAISE}(launchId);

        vm.prank(user2);
        launcher.contribute{value: 1 ether}(launchId); // Should fail
    }

    function testFailUnauthorizedLPWithdraw() public {
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch("Test", "TEST", "ipfs://test");

        vm.prank(user1);
        launcher.contribute{value: TARGET_RAISE}(launchId);

        vm.warp(block.timestamp + 180 days);

        vm.prank(user1); // Not the creator
        launcher.withdrawLP(launchId);
    }

    function testSaleProgress() public {
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch("Test", "TEST", "ipfs://test");

        // Make partial contribution
        uint256 contribution = TARGET_RAISE / 2;
        vm.prank(user1);
        launcher.contribute{value: contribution}(launchId);

        // Check sale progress
        (
            uint256 tokenPrice,
            uint256 tokensForSale,
            uint256 tokensSold,
            uint256 totalRaised,
            bool launched,
            uint256 remainingTokens
        ) = launcher.getSaleInfo(launchId);

        assertEq(totalRaised, contribution, "Incorrect total raised");
        assertTrue(!launched, "Should not be launched yet");
        assertTrue(tokensSold > 0, "No tokens sold");
        assertTrue(remainingTokens > 0, "No tokens remaining");
        assertTrue(tokensSold < tokensForSale, "Too many tokens sold");
    }

    function testContributionEdgeCases() public {
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch("Test", "TEST", "ipfs://test");

        // Test minimum viable contribution
        uint256 minAmount = 1 wei;
        vm.prank(user1);
        launcher.contribute{value: minAmount}(launchId);

        // Test very large contribution
        uint256 largeAmount = 5000 ether;
        vm.prank(user2);
        launcher.contribute{value: largeAmount}(launchId);

        // Verify token distribution is proportional
        (address tokenAddress,,,,,, ) = launcher.getLaunchInfo(launchId);
        LaunchToken token = LaunchToken(tokenAddress);

        uint256 user1Tokens = token.balanceOf(user1);
        uint256 user2Tokens = token.balanceOf(user2);

        assertApproxEqRel(
            user1Tokens * largeAmount,
            user2Tokens * minAmount,
            0.01e18
        );
    }

    function testPartialRaise() public {
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch("Test", "TEST", "ipfs://test");

        // Contribute less than target
        uint256 partialAmount = TARGET_RAISE / 2;
        vm.prank(user1);
        launcher.contribute{value: partialAmount}(launchId);

        // Check state
        (,,,, uint256 totalRaised, bool launched,) = launcher.getLaunchInfo(launchId);
        assertEq(totalRaised, partialAmount);
        assertFalse(launched);

        // Tokens should still be distributed
        (address tokenAddress,,,,,, ) = launcher.getLaunchInfo(launchId);
        LaunchToken token = LaunchToken(tokenAddress);
        assertTrue(token.balanceOf(user1) > 0);
    }

    function testExtraContribution() public {
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch("Test", "TEST", "ipfs://test");

        // Send more than needed
        uint256 extraAmount = TARGET_RAISE + 1 ether;

        vm.prank(user1);
        launcher.contribute{value: extraAmount}(launchId);

        // Verify total raised doesn't exceed target
        (,,,, uint256 totalRaised,,) = launcher.getLaunchInfo(launchId);
        assertLe(totalRaised, TARGET_RAISE);
    }

    function testTokenPriceEdgeCases() public {
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch("Test", "TEST", "ipfs://test");

        (uint256 tokenPrice,,,,,) = launcher.getSaleInfo(launchId);

        // Test price calculation with very small purchase
        uint256 tinyAmount = 1 wei;
        uint256 expectedTokens = (tinyAmount * 1e18) / tokenPrice;
        assertTrue(expectedTokens > 0, "Should get some tokens for any valid contribution");

        // Test price calculation with very large purchase
        uint256 largeAmount = TARGET_RAISE;
        uint256 expectedLargeTokens = (largeAmount * 1e18) / tokenPrice;
        assertTrue(expectedLargeTokens < TOTAL_SUPPLY, "Cannot get more tokens than total supply");
    }

    function testFailInsufficientTokenBalance() public {
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch("Test", "TEST", "ipfs://test");

        // Simulate launcher having no tokens
        address tokenAddress = launcher.getLaunchInfo(launchId).tokenAddress;
        vm.mockCall(
            tokenAddress,
            abi.encodeWithSelector(IERC20.transfer.selector),
            abi.encode(false)
        );

        vm.prank(user1);
        launcher.contribute{value: 1 ether}(launchId);
    }

    function testFailZeroContribution() public {
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch("Test", "TEST", "ipfs://test");

        vm.prank(user1);
        vm.expectRevert(FiveFiveFiveLauncher.InvalidPayment.selector);
        launcher.contribute{value: 0}(launchId);
    }

    function testRemainingTokenCalculation() public {
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch("Test", "TEST", "ipfs://test");

        // Get initial sale info
        (,uint256 tokensForSale,,,, uint256 initialRemaining) = launcher.getSaleInfo(launchId);
        assertEq(initialRemaining, tokensForSale, "All tokens should be available initially");

        // Make partial purchase
        vm.prank(user1);
        launcher.contribute{value: TARGET_RAISE / 2}(launchId);

        // Check remaining tokens
        (,,,,, uint256 remaining) = launcher.getSaleInfo(launchId);
        assertTrue(remaining < tokensForSale, "Remaining tokens should decrease");
        assertTrue(remaining > 0, "Should still have tokens available");
    }

    function testFailExcessiveContribution() public {
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch("Test", "TEST", "ipfs://test");

        vm.prank(user1);
        launcher.contribute{value: TARGET_RAISE}(launchId);

        // Try to contribute after target reached
        vm.prank(user2);
        vm.expectRevert(FiveFiveFiveLauncher.AlreadyLaunched.selector);
        launcher.contribute{value: 1 ether}(launchId);
    }

    function testExactTargetContribution() public {
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch("Test", "TEST", "ipfs://test");

        vm.prank(user1);
        launcher.contribute{value: TARGET_RAISE}(launchId);

        (,,,, uint256 totalRaised, bool launched,) = launcher.getLaunchInfo(launchId);
        assertEq(totalRaised, TARGET_RAISE, "Should accept exact target amount");
        assertTrue(launched, "Should be launched");
    }

    function testLPTokenBalanceAfterCreation() public {
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch("Test", "TEST", "ipfs://test");

        vm.prank(user1);
        launcher.contribute{value: TARGET_RAISE}(launchId);

        (address tokenAddress,,,,,, ) = launcher.getLaunchInfo(launchId);
        address pair = factory.getPair(tokenAddress, address(weth));

        uint256 lpBalance = IERC20(pair).balanceOf(address(launcher));
        assertTrue(lpBalance > 0, "Should have LP tokens");

        // Try early withdrawal
        vm.prank(creator);
        vm.expectRevert(FiveFiveFiveLauncher.LPStillLocked.selector);
        launcher.withdrawLP(launchId);
    }

    receive() external payable {}
}

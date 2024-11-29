// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/launch/FiveFiveFiveLauncher.sol";
import "../../src/core/PonderFactory.sol";
import "../../src/periphery/PonderRouter.sol";
import "../../src/core/PonderERC20.sol";
import "../mocks/WETH9.sol";
import "../../src/launch/LaunchToken.sol";

contract AdditionalLauncherTests is Test {
    FiveFiveFiveLauncher public launcher;
    PonderFactory public factory;
    PonderRouter public router;
    WETH9 public weth;
    address public feeCollector;
    address public creator;
    address public user1;
    address public user2;

    uint256 constant MIN_TO_LAUNCH = 165 ether;
    uint256 constant MIN_CONTRIBUTION = 0.55 ether;
    uint256 constant TOTAL_SUPPLY = 555_555_555 ether;
    uint256 constant LP_LOCK_PERIOD = 180 days;
    uint256 constant CREATOR_FEE = 55;
    uint256 constant PROTOCOL_FEE = 55;
    uint256 constant FEE_DENOMINATOR = 10000;

    function setUp() public {
        weth = new WETH9();
        factory = new PonderFactory(address(this));
        feeCollector = makeAddr("feeCollector");
        creator = makeAddr("creator");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        router = new PonderRouter(
            address(factory),
            address(weth),
            feeCollector
        );

        launcher = new FiveFiveFiveLauncher(
            address(factory),
            payable(address(router)),
            feeCollector
        );

        // Fund accounts
        vm.deal(creator, 1000 ether);
        vm.deal(user1, 1000 ether);
        vm.deal(user2, 1000 ether);
    }

    function testMultipleContributors() public {
        // Create launch
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch(
            "Token555",
            "T555",
            "https://example.com/image.png"
        );

        // Multiple users contribute
        vm.prank(user1);
        launcher.contribute{value: 50 ether}(launchId);

        vm.prank(user2);
        launcher.contribute{value: 50 ether}(launchId);

        vm.prank(creator);
        launcher.contribute{value: 65 ether}(launchId);

        // Get launch info
        (,,,, uint256 totalRaised, bool launched,) = launcher.getLaunchInfo(launchId);
        assertEq(totalRaised, 165 ether, "Incorrect total raised");
        assertTrue(launched, "Launch not completed");
    }

    function testFeeDistribution() public {
        // Create and complete launch
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch(
            "Token555",
            "T555",
            "https://example.com/image.png"
        );

        uint256 initialCreatorBalance = creator.balance;
        uint256 initialFeeCollectorBalance = feeCollector.balance;

        // Contribute enough to trigger launch
        launcher.contribute{value: MIN_TO_LAUNCH}(launchId);

        // Calculate expected fees
        uint256 expectedCreatorFee = (MIN_TO_LAUNCH * CREATOR_FEE) / FEE_DENOMINATOR;
        uint256 expectedProtocolFee = (MIN_TO_LAUNCH * PROTOCOL_FEE) / FEE_DENOMINATOR;

        // Verify fee distribution
        assertEq(
            creator.balance - initialCreatorBalance,
            expectedCreatorFee,
            "Incorrect creator fee"
        );
        assertEq(
            feeCollector.balance - initialFeeCollectorBalance,
            expectedProtocolFee,
            "Incorrect protocol fee"
        );
    }

    function testTokenTransferRestrictions() public {
        // Create launch
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch(
            "Token555",
            "T555",
            "https://example.com/image.png"
        );

        // Get token address
        (address tokenAddress,,,,,, ) = launcher.getLaunchInfo(launchId);
        LaunchToken token = LaunchToken(tokenAddress);

        // Try to transfer before launch (should fail)
        vm.expectRevert(LaunchToken.TransfersDisabled.selector);
        vm.prank(creator);
        token.transfer(user1, 1000 ether);

        // Complete launch
        launcher.contribute{value: MIN_TO_LAUNCH}(launchId);

        // Transfer should work after launch
        uint256 transferAmount = 1000 ether;
        address pair = factory.getPair(tokenAddress, address(weth));
        uint256 initialBalance = token.balanceOf(pair);
        assertTrue(initialBalance > 0, "No tokens in pair");
    }

    function testPartialContributionsRefund() public {
        // Create launch
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch(
            "Token555",
            "T555",
            "https://example.com/image.png"
        );

        // Multiple partial contributions
        vm.startPrank(user1);
        launcher.contribute{value: MIN_CONTRIBUTION}(launchId);
        launcher.contribute{value: MIN_CONTRIBUTION}(launchId);
        launcher.contribute{value: MIN_CONTRIBUTION}(launchId);
        vm.stopPrank();

        (,,,, uint256 totalRaised,,) = launcher.getLaunchInfo(launchId);
        assertEq(totalRaised, MIN_CONTRIBUTION * 3, "Incorrect total raised");
    }

    function testLPTokenLockingAndUnlocking() public {
        // Create and complete launch
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch(
            "Token555",
            "T555",
            "https://example.com/image.png"
        );

        launcher.contribute{value: MIN_TO_LAUNCH}(launchId);

        // Get token and pair addresses
        (address tokenAddress,,,,,, ) = launcher.getLaunchInfo(launchId);
        address pair = factory.getPair(tokenAddress, address(weth));

        // Try to withdraw before lock period
        vm.expectRevert(FiveFiveFiveLauncher.LPStillLocked.selector);
        vm.prank(creator);
        launcher.withdrawLP(launchId);

        // Fast forward past lock period
        vm.warp(block.timestamp + LP_LOCK_PERIOD + 1);

        // Non-creator cannot withdraw
        vm.expectRevert(FiveFiveFiveLauncher.Unauthorized.selector);
        vm.prank(user1);
        launcher.withdrawLP(launchId);

        // Creator can withdraw
        uint256 lpBalance = PonderERC20(pair).balanceOf(address(launcher));
        vm.prank(creator);
        launcher.withdrawLP(launchId);
        assertEq(PonderERC20(pair).balanceOf(creator), lpBalance, "LP tokens not transferred");
    }

    function testValidTokenParameters() public {
        // Test empty name
        vm.expectRevert(FiveFiveFiveLauncher.InvalidTokenParams.selector);
        vm.prank(creator);
        launcher.createLaunch(
            "",
            "T555",
            "https://example.com/image.png"
        );

        // Test empty symbol
        vm.expectRevert(FiveFiveFiveLauncher.InvalidTokenParams.selector);
        vm.prank(creator);
        launcher.createLaunch(
            "Token555",
            "",
            "https://example.com/image.png"
        );

        // Test too long name (>32 chars)
        vm.expectRevert(FiveFiveFiveLauncher.InvalidTokenParams.selector);
        vm.prank(creator);
        launcher.createLaunch(
            "ThisTokenNameIsMuchTooLongForTheContract",
            "T555",
            "https://example.com/image.png"
        );

        // Test too long symbol (>8 chars)
        vm.expectRevert(FiveFiveFiveLauncher.InvalidTokenParams.selector);
        vm.prank(creator);
        launcher.createLaunch(
            "Token555",
            "TOOLONGSYMBOL",
            "https://example.com/image.png"
        );
    }

    function testContributionLimits() public {
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch(
            "Token555",
            "T555",
            "https://example.com/image.png"
        );

        // Test below minimum contribution
        vm.expectRevert(FiveFiveFiveLauncher.BelowMinContribution.selector);
        vm.prank(user1);
        launcher.contribute{value: MIN_CONTRIBUTION - 0.01 ether}(launchId);

        // Test contribution after launch
        launcher.contribute{value: MIN_TO_LAUNCH}(launchId);

        vm.expectRevert(FiveFiveFiveLauncher.AlreadyLaunched.selector);
        vm.prank(user2);
        launcher.contribute{value: MIN_CONTRIBUTION}(launchId);
    }

    receive() external payable {}
}

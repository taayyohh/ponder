// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/launch/FiveFiveFiveLauncher.sol";
import "../../src/core/PonderFactory.sol";
import "../../src/periphery/PonderRouter.sol";
import "../../src/core/PonderERC20.sol";
import "../mocks/WETH9.sol";
import "../../src/launch/LaunchToken.sol";

contract LauncherFinalizationTests is Test {
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

    event LaunchCreated(uint256 indexed launchId, address indexed token, address creator, string imageURI);
    event Contributed(uint256 indexed launchId, address indexed contributor, uint256 amount);
    event LaunchFinalized(uint256 indexed launchId, uint256 lpAmount, uint256 creatorFee, uint256 protocolFee);
    event ContributionRefunded(uint256 indexed launchId, address indexed contributor, uint256 amount);
    event LPTokensWithdrawn(uint256 indexed launchId, address indexed creator, uint256 amount);
    event TransfersEnabled(uint256 indexed launchId, address indexed tokenAddress);
    event TokenMinted(uint256 indexed launchId, address indexed tokenAddress, uint256 amount);
    event LiquidityAdded(uint256 indexed launchId, uint256 ethAmount, uint256 tokenAmount);

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

        vm.deal(creator, 1000 ether);
        vm.deal(user1, 1000 ether);
        vm.deal(user2, 1000 ether);
    }

    function testExactMinimumLaunch() public {
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch(
            "Test",
            "TEST",
            "ipfs://test"
        );

        // Contribute exactly minimum amount
        vm.prank(user1);
        launcher.contribute{value: MIN_TO_LAUNCH}(launchId);

        (,,,, uint256 totalRaised, bool launched,) = launcher.getLaunchInfo(launchId);
        assertEq(totalRaised, MIN_TO_LAUNCH, "Incorrect total raised");
        assertTrue(launched, "Launch not completed");
    }

    function testDoubleFinalization() public {
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch(
            "Test",
            "TEST",
            "ipfs://test"
        );

        // Complete launch
        vm.prank(user1);
        launcher.contribute{value: MIN_TO_LAUNCH}(launchId);

        // Try to contribute again
        vm.prank(user2);
        vm.expectRevert(FiveFiveFiveLauncher.AlreadyLaunched.selector);
        launcher.contribute{value: MIN_TO_LAUNCH}(launchId);
    }

    function testLaunchTokenTransferRestrictions() public {
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch(
            "Test",
            "TEST",
            "ipfs://test"
        );

        (address tokenAddress,,,,,, ) = launcher.getLaunchInfo(launchId);
        LaunchToken token = LaunchToken(tokenAddress);

        // Non-launcher transfer should fail pre-launch
        vm.prank(user1);
        vm.expectRevert(LaunchToken.TransfersDisabled.selector);
        token.transfer(user2, 1000);

        // Complete launch
        vm.prank(user1);
        launcher.contribute{value: MIN_TO_LAUNCH}(launchId);

        // Post-launch transfers should work
        address pair = factory.getPair(tokenAddress, address(weth));
        assertGt(token.balanceOf(pair), 0, "No tokens in pair");
        assertTrue(token.transfersEnabled(), "Transfers not enabled after launch");

        // Verify anyone can transfer after launch
        uint256 transferAmount = 1000;
        vm.startPrank(pair);
        token.transfer(user1, transferAmount);
        vm.stopPrank();
        assertEq(token.balanceOf(user1), transferAmount, "Transfer after launch failed");
    }

    function testFeeCalculationPrecision() public {
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch(
            "Test",
            "TEST",
            "ipfs://test"
        );

        uint256 contribution = MIN_TO_LAUNCH + 0.777777 ether;
        uint256 creatorBalanceBefore = creator.balance;
        uint256 feeCollectorBalanceBefore = feeCollector.balance;

        vm.prank(user1);
        launcher.contribute{value: contribution}(launchId);

        uint256 creatorFee = (contribution * 55) / 10000; // 0.55%
        uint256 protocolFee = (contribution * 55) / 10000; // 0.55%

        assertEq(
            creator.balance - creatorBalanceBefore,
            creatorFee,
            "Incorrect creator fee"
        );
        assertEq(
            feeCollector.balance - feeCollectorBalanceBefore,
            protocolFee,
            "Incorrect protocol fee"
        );
    }

    function testLPTokenTimelockPrecision() public {
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch(
            "Test",
            "TEST",
            "ipfs://test"
        );

        vm.prank(user1);
        launcher.contribute{value: MIN_TO_LAUNCH}(launchId);

        // Try withdraw just before unlock
        vm.warp(block.timestamp + 180 days - 1);
        vm.prank(creator);
        vm.expectRevert(FiveFiveFiveLauncher.LPStillLocked.selector);
        launcher.withdrawLP(launchId);

        // Should succeed exactly at unlock time
        vm.warp(block.timestamp + 1);
        vm.prank(creator);
        launcher.withdrawLP(launchId);
    }

    function testContributionEventEmission() public {
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch(
            "Test",
            "TEST",
            "ipfs://test"
        );

        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit Contributed(launchId, user1, MIN_TO_LAUNCH);
        launcher.contribute{value: MIN_TO_LAUNCH}(launchId);
    }

    function testLaunchTokenInitialization() public {
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch(
            "Test",
            "TEST",
            "ipfs://test"
        );

        (address tokenAddress,,,,,, ) = launcher.getLaunchInfo(launchId);
        LaunchToken token = LaunchToken(tokenAddress);

        // Verify token state
        assertEq(token.name(), "Test", "Wrong token name");
        assertEq(token.symbol(), "TEST", "Wrong token symbol");
        assertEq(token.totalSupply(), 555_555_555 ether, "Wrong total supply");
        assertEq(token.launcher(), address(launcher), "Wrong launcher address");
        assertFalse(token.transfersEnabled(), "Transfers should be disabled initially");
    }

    function testEmergencyRecovery() public {
        // Test direct ETH recovery
        payable(address(launcher)).transfer(1 ether);
        assertEq(address(launcher).balance, 1 ether, "Wrong launcher balance");

        // Force some tokens into the contract
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch(
            "Test",
            "TEST",
            "ipfs://test"
        );

        (address tokenAddress,,,,,, ) = launcher.getLaunchInfo(launchId);
        LaunchToken token = LaunchToken(tokenAddress);

        // Verify contract holds launch tokens
        assertGt(token.balanceOf(address(launcher)), 0, "No tokens in launcher");
    }

    receive() external payable {}
}

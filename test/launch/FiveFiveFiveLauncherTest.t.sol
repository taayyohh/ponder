// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/launch/FiveFiveFiveLauncher.sol";
import "../../src/core/PonderFactory.sol";
import "../../src/periphery/PonderRouter.sol";
import "../../src/core/PonderERC20.sol";
import "../mocks/WETH9.sol";
import "../../src/launch/LaunchToken.sol";

contract FiveFiveFiveLauncherTest is Test {
    FiveFiveFiveLauncher public launcher;
    PonderFactory public factory;
    PonderRouter public router;
    WETH9 public weth;
    address public feeCollector;
    address public creator;

    // Constants from the launcher contract
    uint256 constant MIN_TO_LAUNCH = 165 ether;
    uint256 constant MIN_CONTRIBUTION = 0.55 ether;
    uint256 constant TOTAL_SUPPLY = 555_555_555 ether;
    uint256 constant LP_LOCK_PERIOD = 180 days;

    event LaunchCreated(uint256 indexed launchId, address indexed token, address creator, string imageURI);
    event Contributed(uint256 indexed launchId, address indexed contributor, uint256 amount);
    event LaunchFinalized(uint256 indexed launchId, uint256 lpAmount, uint256 creatorFee, uint256 protocolFee);

    function setUp() public {
        // Deploy WETH first
        weth = new WETH9();

        // Deploy factory
        factory = new PonderFactory(address(this));

        // Setup addresses
        feeCollector = makeAddr("feeCollector");
        creator = makeAddr("creator");

        // Deploy router
        router = new PonderRouter(address(factory), address(weth), feeCollector);

        // Deploy launcher
        launcher = new FiveFiveFiveLauncher(
            address(factory),
            payable(address(router)),  // Cast to payable
            feeCollector
        );

        // Fund accounts
        vm.deal(creator, 1000 ether);
        vm.deal(address(this), 1000 ether);

        // Label addresses
        vm.label(address(weth), "WETH");
        vm.label(address(factory), "Factory");
        vm.label(address(router), "Router");
        vm.label(address(launcher), "Launcher");
        vm.label(feeCollector, "FeeCollector");
        vm.label(creator, "Creator");
    }

    function testCreateLaunch() public {
        vm.startPrank(creator);

        uint256 launchId = launcher.createLaunch(
            "Token555",
            "T555",
            "https://example.com/image.png"
        );

        (
            address tokenAddress,
            string memory name,
            string memory symbol,
            ,,,  // skip other return values
        ) = launcher.getLaunchInfo(launchId);

        assertEq(name, "Token555", "Wrong token name");
        assertEq(symbol, "T555", "Wrong token symbol");
        assertTrue(tokenAddress != address(0), "Token not created");

        LaunchToken token = LaunchToken(tokenAddress);
        assertEq(token.balanceOf(address(launcher)), TOTAL_SUPPLY, "Wrong initial supply");
        vm.stopPrank();
    }

    function testContributeAndLaunch() public {
        // Create launch
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch(
            "Token555",
            "T555",
            "https://example.com/image.png"
        );

        // Make contribution
        vm.deal(address(this), MIN_TO_LAUNCH);
        launcher.contribute{value: MIN_TO_LAUNCH}(launchId);

        // Verify launch completed
        (,,,,, bool launched,) = launcher.getLaunchInfo(launchId);
        assertTrue(launched, "Launch not completed");

        // Get token address
        (address tokenAddress,,,,,, ) = launcher.getLaunchInfo(launchId);

        // Verify LP tokens created
        address pair = factory.getPair(tokenAddress, address(weth));
        assertTrue(pair != address(0), "Pair not created");
        assertTrue(PonderERC20(pair).balanceOf(address(launcher)) > 0, "No LP tokens");
    }

    function testWithdrawLP() public {
        // Create and launch
        vm.startPrank(creator);
        uint256 launchId = launcher.createLaunch(
            "Token555",
            "T555",
            "https://example.com/image.png"
        );
        vm.stopPrank();

        // Contribute to launch
        vm.deal(address(this), MIN_TO_LAUNCH);
        launcher.contribute{value: MIN_TO_LAUNCH}(launchId);

        // Try withdraw before lock (should fail)
        vm.expectRevert(FiveFiveFiveLauncher.LPStillLocked.selector);
        vm.prank(creator);
        launcher.withdrawLP(launchId);

        // Warp past lock period
        vm.warp(block.timestamp + LP_LOCK_PERIOD + 1);

        // Should succeed now
        vm.prank(creator);
        launcher.withdrawLP(launchId);

        // Get token address properly
        (address tokenAddress,,,,,, ) = launcher.getLaunchInfo(launchId);

        // Verify LP transferred
        address pair = factory.getPair(tokenAddress, address(weth));
        assertEq(PonderERC20(pair).balanceOf(address(launcher)), 0, "LP not withdrawn");
        assertTrue(PonderERC20(pair).balanceOf(creator) > 0, "Creator didn't receive LP");
    }

    function testFailInvalidImage() public {
        vm.prank(creator);
        launcher.createLaunch("Token555", "T555", "");
    }

    function testRevertBelowMinContribution() public {
        vm.prank(creator);
        uint256 launchId = launcher.createLaunch(
            "Token555",
            "T555",
            "https://example.com/image.png"
        );

        vm.expectRevert(FiveFiveFiveLauncher.BelowMinContribution.selector);
        launcher.contribute{value: MIN_CONTRIBUTION - 0.01 ether}(launchId);
    }

    receive() external payable {}
}

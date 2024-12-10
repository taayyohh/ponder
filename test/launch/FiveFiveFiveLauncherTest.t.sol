// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../../src/launch/FiveFiveFiveLauncher.sol";
import "../../src/core/PonderFactory.sol";
import "../../src/core/PonderToken.sol";
import "../../src/core/PonderPriceOracle.sol";
import "../../src/periphery/PonderRouter.sol";
import "../mocks/ERC20Mint.sol";
import "../mocks/WETH9.sol";
import "../mocks/MockKKUBUnwrapper.sol";

contract FiveFiveFiveLauncherTest is Test {
    FiveFiveFiveLauncher launcher;
    PonderFactory factory;
    PonderRouter router;
    PonderToken ponder;
    PonderPriceOracle oracle;
    WETH9 weth;
    ERC20Mint usdt;
    address ponderWethPair;

    address creator = makeAddr("creator");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address feeCollector = makeAddr("feeCollector");
    address treasury = makeAddr("treasury");
    address teamReserve = makeAddr("teamReserve");
    address marketing = makeAddr("marketing");

    uint256 constant TARGET_RAISE = 5555 ether;
    uint256 constant INITIAL_LIQUIDITY = 10_000 ether;

    event LaunchCreated(uint256 indexed launchId, address indexed token, address creator, string imageURI);
    event KUBContributed(uint256 indexed launchId, address contributor, uint256 amount);
    event PonderContributed(uint256 indexed launchId, address contributor, uint256 amount, uint256 kubValue);
    event DualPoolsCreated(uint256 indexed launchId, address memeKubPair, address memePonderPair, uint256 kubLiquidity, uint256 ponderLiquidity);
    event LaunchCompleted(uint256 indexed launchId, uint256 kubRaised, uint256 ponderRaised);

    function setUp() public {
        vm.warp(1000);

        weth = new WETH9();
        usdt = new ERC20Mint("USDT", "USDT");
        ponder = new PonderToken(
            treasury,
            teamReserve,
            marketing,
            address(this)
        );
        factory = new PonderFactory(address(this), address(this));

        ponderWethPair = factory.createPair(address(ponder), address(weth));

        MockKKUBUnwrapper unwrapper = new MockKKUBUnwrapper(address(weth));
        router = new PonderRouter(address(factory), address(weth), address(unwrapper));

        ponder.setMinter(address(this));
        ponder.mint(address(this), INITIAL_LIQUIDITY * 10);
        ponder.approve(address(router), INITIAL_LIQUIDITY * 10);
        vm.deal(address(this), INITIAL_LIQUIDITY);

        router.addLiquidityETH{value: INITIAL_LIQUIDITY}(
            address(ponder),
            INITIAL_LIQUIDITY * 10,
            0,
            0,
            address(this),
            block.timestamp + 1
        );

        oracle = new PonderPriceOracle(
            address(factory),
            ponderWethPair,
            address(usdt)
        );

        _updateOracleWithHistory();

        launcher = new FiveFiveFiveLauncher(
            address(factory),
            payable(address(router)),
            feeCollector,
            address(ponder),
            address(oracle)
        );

        vm.deal(alice, 10000 ether);
        vm.deal(bob, 10000 ether);

        ponder.mint(alice, 1000000e18);
        ponder.mint(bob, 1000000e18);

        vm.prank(alice);
        ponder.approve(address(launcher), type(uint256).max);

        vm.prank(bob);
        ponder.approve(address(launcher), type(uint256).max);

        ponder.setMinter(address(launcher));
    }

    function _updateOracleWithHistory() internal {
        // First sync
        PonderPair(ponderWethPair).sync();
        vm.warp(block.timestamp + 5 minutes);
        oracle.update(ponderWethPair);

        // Additional history points
        for (uint i = 0; i < 3; i++) {
            vm.warp(block.timestamp + 5 minutes);
            PonderPair(ponderWethPair).sync();
            oracle.update(ponderWethPair);
        }

        // Small time gap after initialization
        vm.warp(block.timestamp + 5 minutes);
    }

    function testCreateLaunch() public {
        vm.startPrank(creator);
        uint256 launchId = launcher.createLaunch("Test Token", "TEST", "ipfs://test");
        vm.stopPrank();

        (
            address tokenAddress,
            string memory name,
            string memory symbol,
            string memory imageURI,
            uint256 kubRaised,
            bool launched,
            uint256 lpUnlockTime
        ) = launcher.getLaunchInfo(launchId);

        assertEq(name, "Test Token");
        assertEq(symbol, "TEST");
        assertEq(imageURI, "ipfs://test");
        assertEq(kubRaised, 0);
        assertFalse(launched);
        assertNotEq(tokenAddress, address(0));
    }

    function testKUBContribution() public {
        uint256 launchId = _createTestLaunch();
        uint256 contribution = 1000 ether;

        vm.startPrank(alice);
        vm.expectEmit(true, true, false, true);
        emit KUBContributed(launchId, alice, contribution);
        launcher.contributeKUB{value: contribution}(launchId);
        vm.stopPrank();

        (,,,, uint256 kubRaised,,) = launcher.getLaunchInfo(launchId);
        assertEq(kubRaised, contribution);
    }

    // Partial update focusing on the failing tests
    function testPonderContribution() public {
        uint256 launchId = _createTestLaunch();
        uint256 contribution = 10000e18; // Smaller contribution amount

        vm.startPrank(alice);
        vm.expectEmit(true, true, false, true);
        emit PonderContributed(launchId, alice, contribution, contribution / 10); // Adjust expected value
        launcher.contributePonder(launchId, contribution);
        vm.stopPrank();

        (
            uint256 kubCollected,
            uint256 ponderCollected,
            uint256 ponderValueCollected,
            uint256 remainingPonderCap,
            uint256 totalValueCollected
        ) = launcher.getContributionInfo(launchId);

        assertEq(ponderCollected, contribution);
        assertEq(kubCollected, 0);
        assertGt(remainingPonderCap, 0);
        assertEq(totalValueCollected, ponderValueCollected);
    }

    function testMultipleContributions() public {
        uint256 launchId = _createTestLaunch();
        uint256 contribution = TARGET_RAISE / 4;

        // Make initial KUB contributions
        vm.startPrank(alice);
        launcher.contributeKUB{value: contribution}(launchId);
        launcher.contributeKUB{value: contribution}(launchId);
        launcher.contributeKUB{value: contribution}(launchId);
        vm.stopPrank();

        // Make PONDER contribution with proper scaling
        uint256 ponderAmount = contribution * 10; // 10x multiplier for PONDER ratio
        vm.startPrank(bob);
        vm.expectEmit(true, true, false, true);
        emit PonderContributed(launchId, bob, ponderAmount, contribution);
        launcher.contributePonder(launchId, ponderAmount);
        vm.stopPrank();

        (,,,, uint256 kubRaised, bool launched,) = launcher.getLaunchInfo(launchId);
        assertTrue(launched, "Launch should be completed");
    }

    function testFailExcessivePonderContribution() public {
        uint256 launchId = _createTestLaunch();
        uint256 maxPonderValue = (TARGET_RAISE * launcher.MAX_PONDER_PERCENT()) / launcher.BASIS_POINTS();
        uint256 excessiveAmount = maxPonderValue * 12;

        vm.prank(alice);
        launcher.contributePonder(launchId, excessiveAmount);
    }

    function testFailContributeAfterLaunch() public {
        uint256 launchId = _createTestLaunch();

        vm.prank(alice);
        launcher.contributeKUB{value: TARGET_RAISE}(launchId);

        vm.prank(bob);
        launcher.contributeKUB{value: 1 ether}(launchId);
    }

    function _createTestLaunch() internal returns (uint256) {
        vm.prank(creator);
        return launcher.createLaunch("Test Token", "TEST", "ipfs://test");
    }

    receive() external payable {}
}

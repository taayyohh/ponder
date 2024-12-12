// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/launch/FiveFiveFiveLauncher.sol";
import "../../src/core/PonderFactory.sol";
import "../../src/core/PonderToken.sol";
import "../../src/core/PonderPriceOracle.sol";
import "../../src/periphery/PonderRouter.sol";
import "../../src/launch/LaunchToken.sol";
import "../mocks/ERC20.sol";
import "../mocks/WETH9.sol";
import "../mocks/MockKKUBUnwrapper.sol";

contract FiveFiveFiveLauncherTest is Test {
    FiveFiveFiveLauncher launcher;
    PonderFactory factory;
    PonderRouter router;
    PonderToken ponder;
    PonderPriceOracle oracle;
    WETH9 weth;
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
    uint256 constant PONDER_PRICE = 0.1 ether;    // 1 PONDER = 0.1 KUB

    event LaunchCreated(uint256 indexed launchId, address indexed token, address creator, string imageURI);
    event KUBContributed(uint256 indexed launchId, address contributor, uint256 amount);
    event PonderContributed(uint256 indexed launchId, address contributor, uint256 amount, uint256 kubValue);
    event DualPoolsCreated(uint256 indexed launchId, address memeKubPair, address memePonderPair, uint256 kubLiquidity, uint256 ponderLiquidity);
    event LaunchCompleted(uint256 indexed launchId, uint256 kubRaised, uint256 ponderRaised);
    event PonderBurned(uint256 indexed launchId, uint256 amount);

    function setUp() public {
        vm.warp(1000);

        // Deploy core contracts
        weth = new WETH9();
        factory = new PonderFactory(address(this), address(this), address(2), address(3));
        ponder = new PonderToken(treasury, teamReserve, marketing, address(this));

        // Create PONDER/WETH pair
        ponderWethPair = factory.createPair(address(ponder), address(weth));

        // Deploy router with KKUB unwrapper
        MockKKUBUnwrapper unwrapper = new MockKKUBUnwrapper(address(weth));
        router = new PonderRouter(address(factory), address(weth), address(unwrapper));

        // Setup initial PONDER minting and liquidity
        ponder.setMinter(address(this));
        ponder.mint(address(this), INITIAL_LIQUIDITY * 10);
        ponder.approve(address(router), INITIAL_LIQUIDITY * 10);

        // Add initial PONDER/WETH liquidity
        vm.deal(address(this), INITIAL_LIQUIDITY);
        router.addLiquidityETH{value: INITIAL_LIQUIDITY}(
            address(ponder),
            INITIAL_LIQUIDITY * 10,
            0,
            0,
            address(this),
            block.timestamp + 1
        );

        // Deploy and initialize oracle
        oracle = new PonderPriceOracle(
            address(factory),
            ponderWethPair,
            address(weth)
        );

        _initializeOracleHistory();

        // Deploy launcher
        launcher = new FiveFiveFiveLauncher(
            address(factory),
            payable(address(router)),
            feeCollector,
            address(ponder),
            address(oracle)
        );

        // Fund test accounts
        vm.deal(alice, 10000 ether);
        vm.deal(bob, 10000 ether);
        ponder.mint(alice, 100000 ether);
        ponder.mint(bob, 100000 ether);

        vm.prank(alice);
        ponder.approve(address(launcher), type(uint256).max);
        vm.prank(bob);
        ponder.approve(address(launcher), type(uint256).max);

        // Transfer PONDER minting rights to launcher
        ponder.setMinter(address(launcher));
    }

    function testCreateLaunch() public {
        vm.startPrank(creator);
        uint256 launchId = launcher.createLaunch(
            "Test Token",
            "TEST",
            "ipfs://test"
        );
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
        assertTrue(tokenAddress != address(0));
    }

    function testKUBContribution() public {
        uint256 launchId = _createTestLaunch();
        uint256 contribution = 1000 ether;

        vm.startPrank(alice);
        vm.expectEmit(true, true, false, true);
        emit KUBContributed(launchId, alice, contribution);
        launcher.contributeKUB{value: contribution}(launchId);
        vm.stopPrank();

        (uint256 kubCollected, , ,uint256 totalValue) = launcher.getContributionInfo(launchId);
        assertEq(kubCollected, contribution);
        assertEq(totalValue, contribution);
    }

    function testPonderContribution() public {
        uint256 launchId = _createTestLaunch();
        uint256 ponderAmount = 10000 ether;

        vm.startPrank(alice);
        launcher.contributePONDER(launchId, ponderAmount);
        vm.stopPrank();

        (
            uint256 kubCollected,
            uint256 ponderCollected,
            uint256 ponderValueCollected,
            uint256 totalValue
        ) = launcher.getContributionInfo(launchId);

        assertEq(ponderCollected, ponderAmount);
        assertGt(ponderValueCollected, 0);
        assertEq(kubCollected, 0);
        assertEq(totalValue, ponderValueCollected);
    }

    function testCompleteLaunchWithDualPools() public {
        uint256 launchId = _createTestLaunch();

        // KUB contribution
        vm.startPrank(alice);
        launcher.contributeKUB{value: 3000 ether}(launchId);
        vm.stopPrank();

        // PONDER contribution - adjust for 0.1 KUB per PONDER price
        uint256 remainingValueKub = 2555 ether;  // Remaining value in KUB
        uint256 ponderAmount = remainingValueKub * 10;  // Convert KUB to PONDER (1 PONDER = 0.1 KUB)

        vm.startPrank(bob);
        launcher.contributePONDER(launchId, ponderAmount);
        vm.stopPrank();

        // Verify launch completed
        (,,,, uint256 kubRaised, bool launched,) = launcher.getLaunchInfo(launchId);
        assertTrue(launched, "Launch should be completed");

        // Check pool creation
        (
            address memeKubPair,
            address memePonderPair,
            bool hasSecondaryPool
        ) = launcher.getPoolInfo(launchId);

        assertTrue(memeKubPair != address(0), "KUB pool not created");
        assertTrue(memePonderPair != address(0), "PONDER pool not created");
        assertTrue(hasSecondaryPool, "Secondary pool flag not set");

        // Verify pool liquidity
        assertGt(PonderERC20(memeKubPair).totalSupply(), 0, "No KUB pool liquidity");
        assertGt(PonderERC20(memePonderPair).totalSupply(), 0, "No PONDER pool liquidity");
    }

    function testLPLocking() public {
        uint256 launchId = _createTestLaunch();

        // Complete launch
        vm.prank(alice);
        launcher.contributeKUB{value: TARGET_RAISE}(launchId);

        // Try early withdrawal
        vm.startPrank(creator);
        vm.expectRevert(FiveFiveFiveLauncher.LPStillLocked.selector);
        launcher.withdrawLP(launchId);
        vm.stopPrank();

        // Move past lock period
        (,,,,,, uint256 lpUnlockTime) = launcher.getLaunchInfo(launchId);
        vm.warp(lpUnlockTime + 1);

        // Withdraw LP tokens
        vm.startPrank(creator);
        launcher.withdrawLP(launchId);
        vm.stopPrank();

        // Verify LP token receipt
        (address kubPair,,) = launcher.getPoolInfo(launchId);
        assertGt(PonderERC20(kubPair).balanceOf(creator), 0, "Creator should have LP tokens");
    }

    function testExcessKUBContribution() public {
        uint256 launchId = _createTestLaunch();
        uint256 excess = TARGET_RAISE + 1000 ether;
        uint256 balanceBefore = alice.balance;

        vm.prank(alice);
        launcher.contributeKUB{value: excess}(launchId);

        assertEq(
            alice.balance,
            balanceBefore - TARGET_RAISE,
            "Excess KUB should be returned"
        );
    }

    function testPriceProtection() public {
        uint256 launchId = _createTestLaunch();

        // Move time forward past price staleness threshold
        vm.warp(block.timestamp + 3 hours);

        vm.startPrank(alice);
        vm.expectRevert(FiveFiveFiveLauncher.StalePrice.selector);
        launcher.contributePONDER(launchId, 1000 ether);
        vm.stopPrank();
    }

    function _createTestLaunch() internal returns (uint256) {
        vm.prank(creator);
        return launcher.createLaunch("Test Token", "TEST", "ipfs://test");
    }

    function _initializeOracleHistory() internal {
        // Initial sync
        PonderPair(ponderWethPair).sync();
        vm.warp(block.timestamp + 1 hours);
        oracle.update(ponderWethPair);

        // Build price history
        for (uint i = 0; i < 3; i++) {
            vm.warp(block.timestamp + 1 hours);
            PonderPair(ponderWethPair).sync();
            oracle.update(ponderWethPair);
        }
    }

    receive() external payable {}
}

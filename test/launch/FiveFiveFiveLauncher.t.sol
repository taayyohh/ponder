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
    event TokensDistributed(uint256 indexed launchId, address indexed recipient, uint256 amount);
    event DualPoolsCreated(uint256 indexed launchId, address memeKubPair, address memePonderPair, uint256 kubLiquidity, uint256 ponderLiquidity);
    event LaunchCompleted(uint256 indexed launchId, uint256 kubRaised, uint256 ponderRaised);
    event PonderBurned(uint256 indexed launchId, uint256 amount);

    function setUp() public {
        vm.warp(1000);

        // Deploy core contracts
        weth = new WETH9();
        factory = new PonderFactory(address(this), address(this));
        ponder = new PonderToken(treasury, teamReserve, marketing, address(this));

        ponderWethPair = factory.createPair(address(ponder), address(weth));

        MockKKUBUnwrapper unwrapper = new MockKKUBUnwrapper(address(weth));
        router = new PonderRouter(address(factory), address(weth), address(unwrapper));

        // Setup initial PONDER liquidity
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
            address(weth)
        );

        _initializeOracleHistory();

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

        ponder.setMinter(address(launcher));
    }

    function testCreateLaunch() public {
        vm.startPrank(creator);

        FiveFiveFiveLauncher.LaunchParams memory params = FiveFiveFiveLauncher.LaunchParams({
            name: "Test Token",
            symbol: "TEST",
            imageURI: "ipfs://test"
        });

        uint256 launchId = launcher.createLaunch(params);
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

    function _calculateExpectedTokens(
        uint256 contribution,
        uint256 totalSupply,
        uint256 targetRaise
    ) internal pure returns (uint256) {
        // First calculate contributor allocation (70%)
        uint256 contributorTokens = (totalSupply * 70) / 100;

        // Then calculate this contribution's share
        return (contribution * contributorTokens) / targetRaise;
    }

    function testKUBContribution() public {
        uint256 launchId = _createTestLaunch();
        uint256 contribution = 1000 ether;

        // Get actual total supply from token
        (address tokenAddress,,,,,,) = launcher.getLaunchInfo(launchId);
        uint256 totalSupply = LaunchToken(tokenAddress).TOTAL_SUPPLY();

        // Calculate expected tokens
        uint256 contributorTokens = (totalSupply * 70) / 100;
        uint256 expectedTokens = (contribution * contributorTokens) / TARGET_RAISE;

        console.log("Total Supply:", totalSupply);
        console.log("Contributor Tokens:", contributorTokens);
        console.log("Expected Tokens:", expectedTokens);

        vm.startPrank(alice);
        launcher.contributeKUB{value: contribution}(launchId);

        // Get actual tokens received
        (,,,uint256 tokensReceived) = launcher.getContributorInfo(launchId, alice);
        console.log("Actual Tokens Received:", tokensReceived);

        // Let's try to understand the ratio
        console.log("Actual/Expected Ratio:", (tokensReceived * 100) / expectedTokens);

        assertEq(tokensReceived, expectedTokens, "Token distribution incorrect");
        vm.stopPrank();
    }

    function testPonderContribution() public {
        uint256 launchId = _createTestLaunch();
        uint256 ponderAmount = 10000 ether;
        uint256 expectedKubValue = _getPonderValue(ponderAmount);

        (address tokenAddress,,,,,,) = launcher.getLaunchInfo(launchId);
        uint256 totalSupply = LaunchToken(tokenAddress).TOTAL_SUPPLY();
        uint256 contributorTokens = (totalSupply * 70) / 100;
        uint256 expectedTokens = (expectedKubValue * contributorTokens) / TARGET_RAISE;

        vm.startPrank(alice);

        // First expect TokensDistributed event
        vm.expectEmit(true, true, false, true);
        emit TokensDistributed(launchId, alice, expectedTokens);

        // Then expect PonderContributed event
        vm.expectEmit(true, true, false, true);
        emit PonderContributed(launchId, alice, ponderAmount, expectedKubValue);

        launcher.contributePONDER(launchId, ponderAmount);

        (,uint256 ponderContributed, uint256 ponderValue, uint256 tokensReceived) =
                            launcher.getContributorInfo(launchId, alice);

        assertEq(ponderContributed, ponderAmount);
        assertEq(ponderValue, expectedKubValue);
        assertEq(tokensReceived, expectedTokens);

        vm.stopPrank();
    }

    function testCompleteLaunchWithDualPools() public {
        uint256 launchId = _createTestLaunch();

        vm.startPrank(alice);
        launcher.contributeKUB{value: 3000 ether}(launchId);
        vm.stopPrank();

        uint256 remainingValueKub = 2555 ether;
        uint256 ponderAmount = remainingValueKub * 10; // Convert remaining KUB value to PONDER

        vm.startPrank(bob);
        launcher.contributePONDER(launchId, ponderAmount);
        vm.stopPrank();

        (,,,, uint256 kubRaised, bool launched,) = launcher.getLaunchInfo(launchId);
        assertTrue(launched, "Launch should be completed");

        (
            address memeKubPair,
            address memePonderPair,
            bool hasSecondaryPool
        ) = launcher.getPoolInfo(launchId);

        assertTrue(memeKubPair != address(0), "KUB pool not created");
        assertTrue(memePonderPair != address(0), "PONDER pool not created");
        assertTrue(hasSecondaryPool, "Secondary pool flag not set");

        assertGt(PonderERC20(memeKubPair).totalSupply(), 0, "No KUB pool liquidity");
        assertGt(PonderERC20(memePonderPair).totalSupply(), 0, "No PONDER pool liquidity");
    }

    function testTokenAllocation() public {
        uint256 launchId = _createTestLaunch();
        uint256 onePercent = TARGET_RAISE / 100;

        vm.startPrank(alice);
        launcher.contributeKUB{value: onePercent}(launchId);
        vm.stopPrank();

        // Should receive 1% of 70% of total supply
        uint256 expectedTokens = (555_555_555 ether * 70) / 10000;
        (, , , uint256 tokensReceived) = launcher.getContributorInfo(launchId, alice);
        assertEq(tokensReceived, expectedTokens, "Incorrect token allocation");
    }

    function _createTestLaunch() internal returns (uint256) {
        FiveFiveFiveLauncher.LaunchParams memory params = FiveFiveFiveLauncher.LaunchParams({
            name: "Test Token",
            symbol: "TEST",
            imageURI: "ipfs://test"
        });

        vm.prank(creator);
        return launcher.createLaunch(params);
    }

    function _initializeOracleHistory() internal {
        PonderPair(ponderWethPair).sync();
        vm.warp(block.timestamp + 1 hours);
        oracle.update(ponderWethPair);

        for (uint i = 0; i < 3; i++) {
            vm.warp(block.timestamp + 1 hours);
            PonderPair(ponderWethPair).sync();
            oracle.update(ponderWethPair);
        }
    }

    function _getPonderValue(uint256 amount) internal view returns (uint256) {
        return oracle.getCurrentPrice(ponderWethPair, address(ponder), amount);
    }

    receive() external payable {}
}

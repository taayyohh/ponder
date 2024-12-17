// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../mocks/ERC20Mint.sol";
import "../../src/core/PonderPair.sol";
import "../../src/launch/LaunchToken.sol";
import "../../src/core/PonderToken.sol";
import "../mocks/WETH9.sol";

contract MockFactory {
    address public feeTo;
    address public launcher;
    address public ponder;

    mapping(address => mapping(address => address)) public pairs;

    constructor(address _feeTo, address _launcher, address _ponder) {
        feeTo = _feeTo;
        launcher = _launcher;
        ponder = _ponder;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        PonderPair newPair = new PonderPair();
        newPair.initialize(tokenA, tokenB);
        pairs[tokenA][tokenB] = address(newPair);
        pairs[tokenB][tokenA] = address(newPair);
        return address(newPair);
    }
}

contract PonderPairTest is Test {
    PonderPair standardPair;
    PonderPair kubPair;
    PonderPair ponderPair;
    ERC20Mint token0;
    ERC20Mint token1;
    LaunchToken launchToken;
    PonderToken ponder;
    WETH9 weth;
    MockFactory factory;

    // Users for testing
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address creator = makeAddr("creator");
    address treasury = makeAddr("treasury");

    // Common amounts
    uint256 constant INITIAL_LIQUIDITY_AMOUNT = 10000e18;
    uint256 constant SWAP_AMOUNT = 1000e18;

    function setUp() public {
        // Deploy standard tokens
        token0 = new ERC20Mint("Token A", "TKNA");
        token1 = new ERC20Mint("Token B", "TKNB");
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }

        // Deploy WETH and PONDER
        weth = new WETH9();
        ponder = new PonderToken(treasury, treasury, treasury, address(this));

        // Set up mock factory first
        factory = new MockFactory(bob, address(this), address(ponder));

        // Deploy LaunchToken
        launchToken = new LaunchToken(
            "Launch Token",
            "LAUNCH",
            address(this),
            address(factory),
            payable(address(1)), // router not needed for tests
            address(ponder)
        );

        // Set up creator for LaunchToken
        launchToken.setupVesting(creator, INITIAL_LIQUIDITY_AMOUNT);
        launchToken.enableTransfers();

        // Create pairs through factory
        address standardPairAddr = factory.createPair(address(token0), address(token1));
        address kubPairAddr = factory.createPair(address(launchToken), address(weth));
        address ponderPairAddr = factory.createPair(address(launchToken), address(ponder));

        // Get pair instances
        standardPair = PonderPair(standardPairAddr);
        kubPair = PonderPair(kubPairAddr);
        ponderPair = PonderPair(ponderPairAddr);

        // Set pairs in LaunchToken
        launchToken.setPairs(kubPairAddr, ponderPairAddr);

        // Mint initial tokens to alice for testing
        token0.mint(alice, INITIAL_LIQUIDITY_AMOUNT * 2);
        token1.mint(alice, INITIAL_LIQUIDITY_AMOUNT * 2);
        deal(address(launchToken), alice, INITIAL_LIQUIDITY_AMOUNT * 2);
        deal(address(weth), alice, INITIAL_LIQUIDITY_AMOUNT * 2);
        deal(address(ponder), alice, INITIAL_LIQUIDITY_AMOUNT * 2);

        // Approve tokens
        vm.startPrank(alice);
        token0.approve(address(standardPair), type(uint256).max);
        token1.approve(address(standardPair), type(uint256).max);
        launchToken.approve(address(kubPair), type(uint256).max);
        weth.approve(address(kubPair), type(uint256).max);
        launchToken.approve(address(ponderPair), type(uint256).max);
        ponder.approve(address(ponderPair), type(uint256).max);
        vm.stopPrank();
    }

    function testStandardSwap() public {
        addInitialLiquidity(standardPair, token0, token1, INITIAL_LIQUIDITY_AMOUNT);

        vm.startPrank(alice);
        token0.transfer(address(standardPair), SWAP_AMOUNT);
        standardPair.swap(0, 900e18, alice, "");
        vm.stopPrank();

        assertGt(token1.balanceOf(alice), 0, "Should have received token1");
        (uint112 reserve0, uint112 reserve1,) = standardPair.getReserves();
        assertGt(reserve0, INITIAL_LIQUIDITY_AMOUNT, "Reserve0 should have increased");
        assertLt(reserve1, INITIAL_LIQUIDITY_AMOUNT, "Reserve1 should have decreased");
    }

    function testKubPairFees() public {
        addInitialLiquidity(kubPair, launchToken, IERC20(address(weth)), INITIAL_LIQUIDITY_AMOUNT);

        uint256 creatorBalanceBefore = launchToken.balanceOf(creator);
        uint256 protocolBalanceBefore = launchToken.balanceOf(bob); // Changed to bob as feeTo

        vm.startPrank(alice);
        launchToken.transfer(address(kubPair), SWAP_AMOUNT);
        kubPair.swap(0, 900e18, alice, "");
        vm.stopPrank();

        uint256 expectedProtocolFee = (SWAP_AMOUNT * 20) / 10000;  // 0.2%
        uint256 expectedCreatorFee = (SWAP_AMOUNT * 10) / 10000;   // 0.1%

        assertEq(
            launchToken.balanceOf(creator) - creatorBalanceBefore,
            expectedCreatorFee,
            "Incorrect creator fee for KUB pair"
        );
        assertEq(
            launchToken.balanceOf(bob) - protocolBalanceBefore,    // Changed to bob
            expectedProtocolFee,
            "Incorrect protocol fee for KUB pair"
        );
    }

    function testBurnComplete() public {
        // Get initial state
        uint256 initialBalance0 = token0.balanceOf(alice);
        uint256 initialBalance1 = token1.balanceOf(alice);

        // Add liquidity with INITIAL_LIQUIDITY_AMOUNT
        uint256 initialLiquidity = addInitialLiquidity(standardPair, token0, token1, INITIAL_LIQUIDITY_AMOUNT);

        // Burn all liquidity
        vm.startPrank(alice);
        standardPair.transfer(address(standardPair), initialLiquidity);
        standardPair.burn(alice);
        vm.stopPrank();

        // Verify results
        assertEq(standardPair.balanceOf(alice), 0, "Should have no LP tokens");
        uint256 minLiquidity = standardPair.MINIMUM_LIQUIDITY();

        // Compare final balance with initial balance
        assertEq(
            token0.balanceOf(alice) - (initialBalance0 - INITIAL_LIQUIDITY_AMOUNT),
            INITIAL_LIQUIDITY_AMOUNT - minLiquidity,
            "Should have received all token0 minus MINIMUM_LIQUIDITY"
        );
        assertEq(
            token1.balanceOf(alice) - (initialBalance1 - INITIAL_LIQUIDITY_AMOUNT),
            INITIAL_LIQUIDITY_AMOUNT - minLiquidity,
            "Should have received all token1 minus MINIMUM_LIQUIDITY"
        );
    }

    function addInitialLiquidity(
        PonderPair pair,
        IERC20 tokenA,
        IERC20 tokenB,
        uint256 amount
    ) internal returns (uint256 liquidity) {
        vm.startPrank(alice);
        tokenA.transfer(address(pair), amount);
        tokenB.transfer(address(pair), amount);
        liquidity = pair.mint(alice);
        vm.stopPrank();

        return liquidity;
    }

    function testFailSwapInsufficientLiquidity() public {
        vm.startPrank(alice);
        token0.transfer(address(standardPair), SWAP_AMOUNT);
        standardPair.swap(0, SWAP_AMOUNT, alice, "");
        vm.stopPrank();
    }

    function testBurnPartial() public {
        uint256 initialLiquidity = addInitialLiquidity(standardPair, token0, token1, INITIAL_LIQUIDITY_AMOUNT);
        uint256 burnAmount = initialLiquidity / 2;

        vm.startPrank(alice);
        standardPair.transfer(address(standardPair), burnAmount);
        standardPair.burn(alice);
        vm.stopPrank();

        assertEq(standardPair.balanceOf(alice), burnAmount, "Should have half LP tokens remaining");
    }

    function testFailBurnInsufficientLiquidity() public {
        vm.startPrank(alice);
        standardPair.burn(alice);
        vm.stopPrank();
    }

    function testSync() public {
        addInitialLiquidity(standardPair, token0, token1, INITIAL_LIQUIDITY_AMOUNT);

        uint256 extraAmount = 1000e18;
        token0.mint(address(standardPair), extraAmount);
        token1.mint(address(standardPair), extraAmount);

        standardPair.sync();

        (uint112 reserve0, uint112 reserve1,) = standardPair.getReserves();
        assertEq(reserve0, INITIAL_LIQUIDITY_AMOUNT + extraAmount, "Reserve0 not synced");
        assertEq(reserve1, INITIAL_LIQUIDITY_AMOUNT + extraAmount, "Reserve1 not synced");
    }

    function testSkim() public {
        addInitialLiquidity(standardPair, token0, token1, INITIAL_LIQUIDITY_AMOUNT);

        uint256 extraAmount = 1000e18;
        token0.mint(address(standardPair), extraAmount);
        token1.mint(address(standardPair), extraAmount);

        uint256 aliceBalance0Before = token0.balanceOf(alice);
        uint256 aliceBalance1Before = token1.balanceOf(alice);

        standardPair.skim(alice);

        assertEq(
            token0.balanceOf(alice) - aliceBalance0Before,
            extraAmount,
            "Incorrect token0 skim amount"
        );
        assertEq(
            token1.balanceOf(alice) - aliceBalance1Before,
            extraAmount,
            "Incorrect token1 skim amount"
        );
    }

    function testStandardFeeCollection() public {
        addInitialLiquidity(standardPair, token0, token1, INITIAL_LIQUIDITY_AMOUNT);

        vm.startPrank(alice);
        token0.transfer(address(standardPair), SWAP_AMOUNT);
        standardPair.swap(0, 900e18, alice, "");
        vm.stopPrank();

        token0.mint(alice, INITIAL_LIQUIDITY_AMOUNT);
        token1.mint(alice, INITIAL_LIQUIDITY_AMOUNT);

        vm.startPrank(alice);
        token0.transfer(address(standardPair), INITIAL_LIQUIDITY_AMOUNT);
        token1.transfer(address(standardPair), INITIAL_LIQUIDITY_AMOUNT);
        standardPair.mint(alice);
        vm.stopPrank();

        assertGt(standardPair.balanceOf(bob), 0, "Should have collected fees");
    }
}

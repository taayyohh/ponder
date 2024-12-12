// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../mocks/ERC20Mint.sol";
import "../../src/core/PonderPair.sol";
import "../../src/core/PonderFactory.sol";
import "../../src/core/PonderStaking.sol";
import "../../src/periphery/PonderRouter.sol";

contract PonderPairTest is Test {
    PonderPair pair;
    ERC20Mint token0;
    ERC20Mint token1;
    ERC20Mint stablecoin;
    PonderFactory factory;
    PonderStaking staking;
    MockRouter router;

    // Users for testing
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address treasury = makeAddr("treasury");

    // Common amounts
    uint256 constant INITIAL_LIQUIDITY_AMOUNT = 10000e18;

    function setUp() public {
        // Deploy tokens
        token0 = new ERC20Mint("Token A", "TKNA");
        token1 = new ERC20Mint("Token B", "TKNB");
        stablecoin = new ERC20Mint("USDT", "USDT");

        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }

        // Deploy router mock
        router = new MockRouter();

        // Deploy factory with required parameters
        factory = new PonderFactory(
            address(this), // feeToSetter
            address(0),    // launcher
            address(stablecoin),
            address(router)
        );

        // Deploy staking contract
        staking = new PonderStaking(address(token0), address(stablecoin));
        factory.setStakingContract(address(staking));

        // Create and initialize pair
        address pairAddress = factory.createPair(address(token0), address(token1));
        pair = PonderPair(pairAddress);

        // Setup initial token balances
        token0.mint(alice, INITIAL_LIQUIDITY_AMOUNT * 2);
        token1.mint(alice, INITIAL_LIQUIDITY_AMOUNT * 2);
        token0.mint(bob, INITIAL_LIQUIDITY_AMOUNT);
        token1.mint(bob, INITIAL_LIQUIDITY_AMOUNT);
    }

    function testSwap() public {
        // First add liquidity
        addInitialLiquidity(INITIAL_LIQUIDITY_AMOUNT);

        uint256 swapAmount = 1000e18;
        uint256 expectedOutput = 900e18; // Approximate due to slippage

        token0.mint(alice, swapAmount);

        vm.startPrank(alice);
        token0.transfer(address(pair), swapAmount);
        pair.swap(0, expectedOutput, alice, "");
        vm.stopPrank();

        // Verify swap results
        assertGt(token1.balanceOf(alice), 0, "Should have received token1");
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        assertGt(reserve0, INITIAL_LIQUIDITY_AMOUNT, "Reserve0 should have increased");
        assertLt(reserve1, INITIAL_LIQUIDITY_AMOUNT, "Reserve1 should have decreased");
    }

    function testFeeSplitting() public {
        // Enable fees and set fee collector
        factory.setFeeTo(treasury);

        // Add initial liquidity
        addInitialLiquidity(INITIAL_LIQUIDITY_AMOUNT);

        // Perform swap to generate fees
        uint256 swapAmount = 1000e18;
        token0.mint(alice, swapAmount);

        vm.startPrank(alice);
        token0.transfer(address(pair), swapAmount);
        pair.swap(0, 900e18, alice, "");
        vm.stopPrank();

        // Add more liquidity to trigger fee mint
        addInitialLiquidity(INITIAL_LIQUIDITY_AMOUNT);

        // Verify fee distribution
        assertGt(pair.balanceOf(treasury), 0, "Should have LP fees");
        assertGt(stablecoin.balanceOf(address(staking)), 0, "Should have staking fees");
    }

    function testFailSwapInsufficientLiquidity() public {
        uint256 swapAmount = 1000e18;
        token0.mint(alice, swapAmount);

        vm.startPrank(alice);
        token0.transfer(address(pair), swapAmount);
        pair.swap(0, swapAmount, alice, "");
        vm.stopPrank();
    }

    function testBurnComplete() public {
        // Add initial liquidity
        uint256 initialLiquidity = addInitialLiquidity(INITIAL_LIQUIDITY_AMOUNT);

        // Burn all LP tokens
        vm.startPrank(alice);
        pair.transfer(address(pair), initialLiquidity);
        pair.burn(alice);
        vm.stopPrank();

        // Verify complete burn
        assertEq(pair.balanceOf(alice), 0, "Should have no LP tokens");
        assertEq(token0.balanceOf(alice), INITIAL_LIQUIDITY_AMOUNT - 1000, "Should have received all token0 minus MINIMUM_LIQUIDITY");
        assertEq(token1.balanceOf(alice), INITIAL_LIQUIDITY_AMOUNT - 1000, "Should have received all token1 minus MINIMUM_LIQUIDITY");
    }

    function testBurnPartial() public {
        uint256 initialLiquidity = addInitialLiquidity(INITIAL_LIQUIDITY_AMOUNT);
        uint256 burnAmount = initialLiquidity / 2;

        vm.startPrank(alice);
        pair.transfer(address(pair), burnAmount);
        pair.burn(alice);
        vm.stopPrank();

        assertEq(pair.balanceOf(alice), burnAmount, "Should have half LP tokens remaining");
    }

    function testFailBurnInsufficientLiquidity() public {
        vm.startPrank(alice);
        pair.burn(alice);
        vm.stopPrank();
    }

    function testSync() public {
        addInitialLiquidity(INITIAL_LIQUIDITY_AMOUNT);

        // Transfer tokens directly to pair without calling mint
        uint256 extraAmount = 1000e18;
        token0.mint(address(pair), extraAmount);
        token1.mint(address(pair), extraAmount);

        pair.sync();

        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        assertEq(reserve0, INITIAL_LIQUIDITY_AMOUNT + extraAmount, "Reserve0 not synced");
        assertEq(reserve1, INITIAL_LIQUIDITY_AMOUNT + extraAmount, "Reserve1 not synced");
    }

    function testSkim() public {
        addInitialLiquidity(INITIAL_LIQUIDITY_AMOUNT);

        // Transfer extra tokens directly to pair
        uint256 extraAmount = 1000e18;
        token0.mint(address(pair), extraAmount);
        token1.mint(address(pair), extraAmount);

        pair.skim(alice);

        assertEq(token0.balanceOf(alice), extraAmount, "Incorrect token0 skim amount");
        assertEq(token1.balanceOf(alice), extraAmount, "Incorrect token1 skim amount");
    }

    // Helper function to add initial liquidity
    function addInitialLiquidity(uint256 amount) internal returns (uint256 liquidity) {
        vm.startPrank(alice);
        token0.transfer(address(pair), amount);
        token1.transfer(address(pair), amount);
        liquidity = pair.mint(alice);
        vm.stopPrank();

        return liquidity;
    }
}

// Mock Router for testing
contract MockRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        // Mock implementation that returns same amount (1:1 conversion)
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        for(uint i = 1; i < path.length; i++) {
            amounts[i] = amountIn;
        }

        // Transfer stablecoin to staking contract
        ERC20Mint(path[path.length-1]).mint(to, amountIn);
        return amounts;
    }
}

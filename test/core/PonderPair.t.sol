// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../mocks/ERC20Mint.sol";
import "../../src/core/PonderPair.sol";

contract PonderPairTest is Test {
    PonderPair pair;
    ERC20Mint token0;
    ERC20Mint token1;

    // Factory interface functions
    address public feeTo;
    address public feeToSetter;

    // Users for testing
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    // Common amounts
    uint256 constant INITIAL_LIQUIDITY_AMOUNT = 10000e18;

    function setUp() public {
        // Deploy tokens with deterministic addresses
        token0 = new ERC20Mint("Token A", "TKNA");
        token1 = new ERC20Mint("Token B", "TKNB");

        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }

        // Deploy and initialize pair
        pair = new PonderPair();
        pair.initialize(address(token0), address(token1));
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

    function testFeeCollection() public {
        // Enable fees
        feeTo = bob;

        // Add initial liquidity
        addInitialLiquidity(INITIAL_LIQUIDITY_AMOUNT);

        // Perform swaps to generate fees
        uint256 swapAmount = 1000e18;
        token0.mint(alice, swapAmount);

        vm.startPrank(alice);
        token0.transfer(address(pair), swapAmount);
        pair.swap(0, 900e18, alice, "");
        vm.stopPrank();

        // Add more liquidity to trigger fee collection
        token0.mint(alice, INITIAL_LIQUIDITY_AMOUNT);
        token1.mint(alice, INITIAL_LIQUIDITY_AMOUNT);

        vm.startPrank(alice);
        token0.transfer(address(pair), INITIAL_LIQUIDITY_AMOUNT);
        token1.transfer(address(pair), INITIAL_LIQUIDITY_AMOUNT);
        pair.mint(alice);
        vm.stopPrank();

        // Verify fee collection
        assertGt(pair.balanceOf(bob), 0, "Should have collected fees");
    }

    // Helper function to add initial liquidity
    function addInitialLiquidity(uint256 amount) internal returns (uint256 liquidity) {
        token0.mint(alice, amount);
        token1.mint(alice, amount);

        vm.startPrank(alice);
        token0.transfer(address(pair), amount);
        token1.transfer(address(pair), amount);
        liquidity = pair.mint(alice);
        vm.stopPrank();

        return liquidity;
    }
}

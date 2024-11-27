// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../mocks/ERC20Mint.sol";
import "../../src/core/PonderFactory.sol";
import "../../src/core/PonderPair.sol";
import "../../src/core/PonderPriceOracle.sol";
import "../../src/core/PonderSafeguard.sol";


contract PonderPriceOracleTest is Test {
    PonderFactory factory;
    PonderPriceOracle oracle;
    PonderSafeguard safeguard;
    ERC20Mint token0;
    ERC20Mint token1;
    PonderPair pair;

    address alice = makeAddr("alice");

    // Testing constants
    uint256 constant INITIAL_LIQUIDITY = 100e18;
    uint256 constant TIME_DELAY = 1 hours;

    function setUp() public {
        // Deploy core contracts
        factory = new PonderFactory(address(this));
        oracle = new PonderPriceOracle(address(factory));
        safeguard = new PonderSafeguard();

        // Set up safeguard in factory
        factory.setSafeguard(address(safeguard));

        // Rest of the setup remains the same...
        token0 = new ERC20Mint("Token A", "TKNA");
        token1 = new ERC20Mint("Token B", "TKNB");

        address pairAddress = factory.createPair(address(token0), address(token1));
        pair = PonderPair(pairAddress);

        vm.startPrank(alice);
        token0.mint(alice, INITIAL_LIQUIDITY);
        token1.mint(alice, INITIAL_LIQUIDITY);
        token0.transfer(address(pair), INITIAL_LIQUIDITY);
        token1.transfer(address(pair), INITIAL_LIQUIDITY);
        pair.mint(alice);
        vm.warp(block.timestamp + 1);
        vm.stopPrank();
    }

    function testInitialObservation() public {
        oracle.update(address(pair));
        assertEq(oracle.observationLength(address(pair)), 1, "Should have one observation");
    }

    function testConsult() public {
        console.log("Initial timestamp:", block.timestamp);

        // Log initial reserves
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        console.log("Initial reserve0:", reserve0);
        console.log("Initial reserve1:", reserve1);

        // Add initial observation
        oracle.update(address(pair));
        console.log("First observation added at:", block.timestamp);

        // Move time forward and make a trade
        vm.warp(block.timestamp + TIME_DELAY);
        console.log("Time moved forward to:", block.timestamp);

        // Make a significant trade to ensure price impact
        vm.startPrank(alice);
        uint256 tradeAmount = 10e18;
        token0.mint(alice, tradeAmount);
        token0.approve(address(pair), tradeAmount);
        token0.transfer(address(pair), tradeAmount);

        // Calculate expected output
        (reserve0, reserve1,) = pair.getReserves();
        console.log("Pre-swap reserve0:", reserve0);
        console.log("Pre-swap reserve1:", reserve1);

        uint256 expectedOutput = (tradeAmount * 997 * uint256(reserve1)) / (uint256(reserve0) * 1000 + (tradeAmount * 997));
        console.log("Expected swap output:", expectedOutput);

        // Execute swap
        pair.swap(0, expectedOutput, alice, "");
        vm.stopPrank();

        // Log post-swap reserves
        (reserve0, reserve1,) = pair.getReserves();
        console.log("Post-swap reserve0:", reserve0);
        console.log("Post-swap reserve1:", reserve1);

        // Add second observation
        oracle.update(address(pair));
        console.log("Second observation added at:", block.timestamp);

        // Move time forward again
        vm.warp(block.timestamp + TIME_DELAY);
        console.log("Final timestamp:", block.timestamp);

        // Get price cumulative values
        uint256 price0Cumulative = pair.price0CumulativeLast();
        uint256 price1Cumulative = pair.price1CumulativeLast();
        console.log("Price0 cumulative:", price0Cumulative);
        console.log("Price1 cumulative:", price1Cumulative);

        // Consult the oracle
        uint256 amountOut = oracle.consult(
            address(pair),
            address(token0),
            1e18,
            uint32(TIME_DELAY)
        );

        console.log("Oracle consult amount out:", amountOut);
        assertGt(amountOut, 0, "Amount out should be greater than 0");
    }

    function testPriceMovement() public {
        console.log("\n=== Starting Price Movement Test ===");

        // Initial state
        oracle.update(address(pair));
        vm.warp(block.timestamp + 1 hours);
        oracle.update(address(pair));

        // Get initial price
        uint256 amountIn = 1e18;
        uint256 initialPrice = oracle.consult(
            address(pair),
            address(token0),
            amountIn,
            uint32(1 hours)
        );
        console.log("Initial price:", initialPrice);

        // Let some time pass
        vm.warp(block.timestamp + 1 hours);

        // Make a very large trade to significantly impact price
        vm.startPrank(alice);

        // Mint and approve a large amount of tokens (5x initial liquidity)
        uint256 swapAmount = INITIAL_LIQUIDITY * 5;
        token0.mint(alice, swapAmount);
        token0.approve(address(pair), swapAmount);

        // Log pre-swap state
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        console.log("Pre-swap - reserve0:", reserve0, "reserve1:", reserve1);

        // Transfer tokens and execute swap
        token0.transfer(address(pair), swapAmount);
        uint256 expectedOutput = (swapAmount * 997 * uint256(reserve1)) /
            (uint256(reserve0) * 1000 + (swapAmount * 997));
        pair.swap(0, expectedOutput, alice, "");
        vm.stopPrank();

        // Log post-swap state
        (reserve0, reserve1,) = pair.getReserves();
        console.log("Post-swap - reserve0:", reserve0, "reserve1:", reserve1);

        // Record post-swap price and wait
        oracle.update(address(pair));
        vm.warp(block.timestamp + 1 hours);
        oracle.update(address(pair));

        // Get new price
        uint256 newPrice = oracle.consult(
            address(pair),
            address(token0),
            amountIn,
            uint32(1 hours)
        );
        console.log("New price:", newPrice);

        // Verify price decreased significantly
        assertTrue(initialPrice > newPrice, "Price should have decreased");
        assertGt(initialPrice - newPrice, initialPrice / 4, "Price should have decreased by at least 25%");
    }

    function testMultipleUpdates() public {
        // Initial observation
        oracle.update(address(pair));

        // Create multiple price updates with trades
        for (uint i = 0; i < 5; i++) {
            vm.warp(block.timestamp + TIME_DELAY);

            // Make a trade
            vm.startPrank(alice);
            token0.mint(alice, 1e18);
            token0.approve(address(pair), 1e18);
            token0.transfer(address(pair), 1e18);

            (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
            uint256 expectedOutput = (1e18 * 997 * uint256(reserve1)) / (uint256(reserve0) * 1000 + (1e18 * 997));

            pair.swap(0, expectedOutput, alice, "");
            vm.stopPrank();

            // Update oracle
            oracle.update(address(pair));
        }

        assertEq(oracle.observationLength(address(pair)), 6, "Should have 6 observations (initial + 5 updates)");

        // Consult for different time periods
        uint256 amountOut = oracle.consult(
            address(pair),
            address(token0),
            1e18,
            uint32(TIME_DELAY)
        );

        assertGt(amountOut, 0, "Amount out should be greater than 0");
        console.log("Multiple updates amount out:", amountOut);
    }

    function testFailInvalidPeriod() public view {
        oracle.consult(
            address(pair),
            address(token0),
            1e18,
            uint32(25 hours) // Greater than PERIOD
        );
    }

    function testFailInvalidToken() public view {
        oracle.consult(
            address(pair),
            address(0x123), // Invalid token address
            1e18,
            uint32(1 hours)
        );
    }

    function testFailNoObservations() public view {
        // Try to consult without any observations
        oracle.consult(
            address(pair),
            address(token0),
            1e18,
            uint32(1 hours)
        );
    }

    function testZeroAmountIn() public {
        // Setup initial state
        oracle.update(address(pair));
        vm.warp(block.timestamp + TIME_DELAY);
        oracle.update(address(pair));

        // Consult with zero amount
        uint256 amountOut = oracle.consult(
            address(pair),
            address(token0),
            0,
            uint32(TIME_DELAY)
        );

        // Zero in should equal zero out
        assertEq(amountOut, 0, "Amount out should be 0 for 0 input");
    }
}

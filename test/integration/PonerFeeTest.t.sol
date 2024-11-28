// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../mocks/ERC20Mint.sol";
import "../../src/core/PonderFactory.sol";
import "../../src/core/PonderPair.sol";
import "../../src/periphery/PonderRouter.sol";

contract PonderFeeTest is Test {
    PonderFactory factory;
    PonderRouter router;
    PonderPair pair;
    ERC20Mint tokenA;
    ERC20Mint tokenB;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address feeCollector = makeAddr("feeCollector");

    uint256 constant INITIAL_LIQUIDITY = 100_000e18;
    uint256 constant SWAP_AMOUNT = 1_000e18;
    uint256 constant MINIMUM_LIQUIDITY = 1000;

    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        // Deploy core contracts
        factory = new PonderFactory(address(this));
        router = new PonderRouter(address(factory), address(0));

        // Deploy tokens
        tokenA = new ERC20Mint("Token A", "TKNA");
        tokenB = new ERC20Mint("Token B", "TKNB");

        // Create pair
        address pairAddress = factory.createPair(address(tokenA), address(tokenB));
        pair = PonderPair(pairAddress);

        // Enable fees
        vm.prank(address(this));
        factory.setFeeTo(feeCollector);

        // Setup initial liquidity
        vm.startPrank(alice);
        tokenA.mint(alice, INITIAL_LIQUIDITY);
        tokenB.mint(alice, INITIAL_LIQUIDITY);
        tokenA.approve(address(router), INITIAL_LIQUIDITY);
        tokenB.approve(address(router), INITIAL_LIQUIDITY);
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            INITIAL_LIQUIDITY,
            INITIAL_LIQUIDITY,
            0,
            0,
            alice,
            block.timestamp
        );
        vm.stopPrank();
    }

    function testBasicFeeCollection() public {
        // Record initial K
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        uint256 initialK = uint256(reserve0) * uint256(reserve1);

        // Do swaps to generate fees
        vm.startPrank(bob);
        tokenA.mint(bob, SWAP_AMOUNT);
        tokenA.approve(address(router), SWAP_AMOUNT);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        router.swapExactTokensForTokens(
            SWAP_AMOUNT,
            0,
            path,
            bob,
            block.timestamp
        );
        vm.stopPrank();

        // Add more liquidity to trigger fee mint
        vm.startPrank(alice);
        tokenA.mint(alice, INITIAL_LIQUIDITY);
        tokenB.mint(alice, INITIAL_LIQUIDITY);
        tokenA.approve(address(router), INITIAL_LIQUIDITY);
        tokenB.approve(address(router), INITIAL_LIQUIDITY);

        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), feeCollector, 247527203253285432);  // Use the actual fee amount

    router.addLiquidity(
            address(tokenA),
            address(tokenB),
            INITIAL_LIQUIDITY,
            INITIAL_LIQUIDITY,
            0,
            0,
            alice,
            block.timestamp
        );
        vm.stopPrank();

        // Check fee collector balance
        uint256 feeBalance = pair.balanceOf(feeCollector);
        assertGt(feeBalance, 0, "No fees collected");

        // Verify K increased
        (reserve0, reserve1,) = pair.getReserves();
        uint256 finalK = uint256(reserve0) * uint256(reserve1);
        assertGt(finalK, initialK, "K should increase");
    }

    function testFeeToggles() public {
        // Initial state - fees enabled
        assertTrue(factory.feeTo() == feeCollector);

        // Do some swaps
        vm.startPrank(bob);
        tokenA.mint(bob, SWAP_AMOUNT);
        tokenA.approve(address(router), SWAP_AMOUNT);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        router.swapExactTokensForTokens(
            SWAP_AMOUNT,
            0,
            path,
            bob,
            block.timestamp
        );
        vm.stopPrank();

        // Add liquidity to collect fees
        vm.startPrank(alice);
        tokenA.mint(alice, INITIAL_LIQUIDITY);
        tokenB.mint(alice, INITIAL_LIQUIDITY);
        tokenA.approve(address(router), INITIAL_LIQUIDITY);
        tokenB.approve(address(router), INITIAL_LIQUIDITY);
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            INITIAL_LIQUIDITY,
            INITIAL_LIQUIDITY,
            0,
            0,
            alice,
            block.timestamp
        );
        vm.stopPrank();

        uint256 initialFeeBalance = pair.balanceOf(feeCollector);
        assertGt(initialFeeBalance, 0, "Should have collected initial fees");

        // Disable fees
        vm.prank(address(this));
        factory.setFeeTo(address(0));

        // Do more swaps
        vm.startPrank(bob);
        tokenA.mint(bob, SWAP_AMOUNT);
        tokenA.approve(address(router), SWAP_AMOUNT);
        router.swapExactTokensForTokens(
            SWAP_AMOUNT,
            0,
            path,
            bob,
            block.timestamp
        );
        vm.stopPrank();

        // Add more liquidity
        vm.startPrank(alice);
        tokenA.mint(alice, INITIAL_LIQUIDITY);
        tokenB.mint(alice, INITIAL_LIQUIDITY);
        tokenA.approve(address(router), INITIAL_LIQUIDITY);
        tokenB.approve(address(router), INITIAL_LIQUIDITY);
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            INITIAL_LIQUIDITY,
            INITIAL_LIQUIDITY,
            0,
            0,
            alice,
            block.timestamp
        );
        vm.stopPrank();

        uint256 finalFeeBalance = pair.balanceOf(feeCollector);
        assertEq(finalFeeBalance, initialFeeBalance, "Fee balance should not change when fees disabled");
    }

    function testKLastTracking() public {
        // Initial state
        (uint112 initialReserve0, uint112 initialReserve1,) = pair.getReserves();
        uint256 initialK = uint256(initialReserve0) * uint256(initialReserve1);

        // Perform swap
        vm.startPrank(bob);
        tokenA.mint(bob, 1e21);
        tokenA.approve(address(router), 1e21);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        router.swapExactTokensForTokens(1e21, 0, path, bob, block.timestamp);
        vm.stopPrank();

        // Check reserves after swap
        (uint112 newReserve0, uint112 newReserve1,) = pair.getReserves();
        uint256 newK = uint256(newReserve0) * uint256(newReserve1);

        assertGt(newK, initialK, "K should increase after swap");
    }

    function testMultipleSwapFeeAccumulation() public {
        uint256 numSwaps = 5;
        uint256 swapSize = SWAP_AMOUNT / numSwaps;

        vm.startPrank(bob);
        tokenA.mint(bob, SWAP_AMOUNT);
        tokenA.approve(address(router), SWAP_AMOUNT);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        // Perform multiple smaller swaps
        for (uint i = 0; i < numSwaps; i++) {
            router.swapExactTokensForTokens(
                swapSize,
                0,
                path,
                bob,
                block.timestamp
            );
        }
        vm.stopPrank();

        // Add liquidity to trigger fee collection
        vm.startPrank(alice);
        tokenA.mint(alice, INITIAL_LIQUIDITY);
        tokenB.mint(alice, INITIAL_LIQUIDITY);
        tokenA.approve(address(router), INITIAL_LIQUIDITY);
        tokenB.approve(address(router), INITIAL_LIQUIDITY);
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            INITIAL_LIQUIDITY,
            INITIAL_LIQUIDITY,
            0,
            0,
            alice,
            block.timestamp
        );
        vm.stopPrank();

        uint256 feeBalance = pair.balanceOf(feeCollector);
        assertGt(feeBalance, 0, "Should have accumulated fees from multiple swaps");
    }
}

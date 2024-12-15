// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../src/core/PonderFactory.sol";
import "../../src/core/PonderPair.sol";
import "../../src/interfaces/IWETH.sol";
import "../../src/periphery/PonderRouter.sol";
import "../mocks/ERC20Mint.sol";
import "../mocks/MockKKUBUnwrapper.sol";
import "../mocks/WETH9.sol";
import "forge-std/Test.sol";

contract PonderRouterTest is Test {
    PonderFactory factory;
    PonderRouter router;
    ERC20Mint tokenA;
    ERC20Mint tokenB;
    ERC20Mint tokenC;
    IWETH weth;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    // Common amounts for testing
    uint256 constant INITIAL_LIQUIDITY = 100e18; // Increased for better swap rates
    uint256 constant MINIMUM_LIQUIDITY = 1000;
    uint256 constant SWAP_AMOUNT = 1e18;
    uint256 deadline;

    function setUp() public {
        // Set deadline to 1 day from now
        deadline = block.timestamp + 1 days;

        // Deploy core contracts
        factory = new PonderFactory(address(this), address(1));
        weth = IWETH(address(new WETH9()));
        MockKKUBUnwrapper unwrapper = new MockKKUBUnwrapper(address(weth));
        router = new PonderRouter(address(factory), address(weth), address(unwrapper));

        // Deploy test tokens
        tokenA = new ERC20Mint("Token A", "TKNA");
        tokenB = new ERC20Mint("Token B", "TKNB");
        tokenC = new ERC20Mint("Token C", "TKNC");

        // Setup initial balances - Increase ETH balance to 200 ETH to ensure enough for all operations
        vm.startPrank(alice);
        tokenA.mint(alice, 1000e18);
        tokenB.mint(alice, 1000e18);
        tokenC.mint(alice, 1000e18);
        vm.deal(alice, 200 ether);  // Increased from 100 to 200 ETH
        vm.stopPrank();
    }

    function testAddLiquidityBasic() public {
        vm.startPrank(alice);

        // Create pair and approve tokens
        address pairAddress = factory.createPair(address(tokenA), address(tokenB));
        tokenA.approve(address(router), INITIAL_LIQUIDITY);
        tokenB.approve(address(router), INITIAL_LIQUIDITY);

        // Add liquidity
        (uint256 amountA, uint256 amountB, uint256 liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            INITIAL_LIQUIDITY,
            INITIAL_LIQUIDITY,
            0, // min amounts
            0,
            alice,
            deadline
        );

        vm.stopPrank();

        // Verify results
        PonderPair pair = PonderPair(pairAddress);
        assertGt(liquidity, 0, "No liquidity minted");
        assertEq(amountA, INITIAL_LIQUIDITY, "Incorrect amount A");
        assertEq(amountB, INITIAL_LIQUIDITY, "Incorrect amount B");
        assertEq(pair.balanceOf(alice), INITIAL_LIQUIDITY - MINIMUM_LIQUIDITY, "LP tokens not minted correctly");
    }

    function testAddLiquidityETH() public {
        vm.startPrank(alice);

        // Create WETH pair
        address pairAddress = factory.createPair(address(tokenA), address(weth));
        tokenA.approve(address(router), INITIAL_LIQUIDITY);

        // Add liquidity with ETH
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = router.addLiquidityETH{
                value: INITIAL_LIQUIDITY
            }(
            address(tokenA),
            INITIAL_LIQUIDITY,
            0, // min amounts
            0,
            alice,
            deadline
        );

        vm.stopPrank();

        // Verify results
        PonderPair pair = PonderPair(pairAddress);
        assertGt(liquidity, 0, "No liquidity minted");
        assertEq(amountToken, INITIAL_LIQUIDITY, "Incorrect token amount");
        assertEq(amountETH, INITIAL_LIQUIDITY, "Incorrect ETH amount");
        assertEq(pair.balanceOf(alice), INITIAL_LIQUIDITY - MINIMUM_LIQUIDITY, "LP tokens not minted correctly");
    }

    function testSwapExactTokensForTokens() public {
        vm.startPrank(alice);

        // Add initial liquidity
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
            deadline
        );

        // Setup swap parameters
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        // Calculate expected amounts
        uint256[] memory expectedAmounts = router.getAmountsOut(SWAP_AMOUNT, path);

        // Approve exact amount needed for swap
        tokenA.approve(address(router), SWAP_AMOUNT);

        uint256 balanceBefore = tokenB.balanceOf(alice);

        // Execute swap
        uint256[] memory amounts = router.swapExactTokensForTokens(
            SWAP_AMOUNT,
            expectedAmounts[1], // Use expected amount as minimum output
            path,
            alice,
            deadline
        );

        uint256 balanceAfter = tokenB.balanceOf(alice);

        vm.stopPrank();

        // Verify results
        assertEq(amounts[0], SWAP_AMOUNT, "Incorrect input amount");
        assertEq(amounts[1], expectedAmounts[1], "Output different from expected");
        assertEq(balanceAfter - balanceBefore, amounts[1], "Incorrect token B balance change");
    }

    function testSwapTokensForExactTokens() public {
        vm.startPrank(alice);

        // Add initial liquidity
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
            deadline
        );

        // Setup swap parameters
        uint256 outputDesired = 0.1e18; // Small amount compared to liquidity
        uint256 maxInput = 1e18;

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        // Calculate required input amount
        uint256[] memory expectedAmounts = router.getAmountsIn(outputDesired, path);

        // Approve exact amount needed
        tokenA.approve(address(router), expectedAmounts[0]);

        uint256 balanceBefore = tokenB.balanceOf(alice);

        // Execute swap
        uint256[] memory amounts = router.swapTokensForExactTokens(
            outputDesired,
            maxInput,
            path,
            alice,
            deadline
        );

        uint256 balanceAfter = tokenB.balanceOf(alice);

        vm.stopPrank();

        // Verify results
        assertEq(amounts[1], outputDesired, "Incorrect output amount");
        assertLt(amounts[0], maxInput, "Input exceeds maximum");
        assertEq(amounts[0], expectedAmounts[0], "Input different from expected");
        assertEq(balanceAfter - balanceBefore, outputDesired, "Incorrect token B balance change");
    }

    function testSwapExactETHForTokens() public {
        vm.startPrank(alice);

        // Add initial liquidity to WETH/TokenA pair
        tokenA.approve(address(router), INITIAL_LIQUIDITY);
        router.addLiquidityETH{value: INITIAL_LIQUIDITY}(
            address(tokenA),
            INITIAL_LIQUIDITY,
            0,
            0,
            alice,
            deadline
        );

        // Setup swap parameters
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(tokenA);

        // Calculate expected amounts
        uint256[] memory expectedAmounts = router.getAmountsOut(SWAP_AMOUNT, path);
        uint256 balanceBefore = tokenA.balanceOf(alice);

        // Execute swap - ensure we have enough ETH
        uint256 ethBalanceBefore = alice.balance;
        require(ethBalanceBefore >= SWAP_AMOUNT, "Insufficient ETH for test");

        uint256[] memory amounts = router.swapExactETHForTokens{value: SWAP_AMOUNT}(
            expectedAmounts[1],
            path,
            alice,
            deadline
        );

        uint256 balanceAfter = tokenA.balanceOf(alice);

        vm.stopPrank();

        // Verify results
        assertEq(amounts[0], SWAP_AMOUNT, "Incorrect input amount");
        assertEq(amounts[1], expectedAmounts[1], "Output different from expected");
        assertEq(balanceAfter - balanceBefore, amounts[1], "Incorrect token balance change");
    }

    function testSwapETHForExactTokens() public {
        vm.startPrank(alice);

        // Add initial liquidity to WETH/TokenA pair
        tokenA.approve(address(router), INITIAL_LIQUIDITY);
        router.addLiquidityETH{value: INITIAL_LIQUIDITY}(
            address(tokenA),
            INITIAL_LIQUIDITY,
            0,
            0,
            alice,
            deadline
        );

        // Setup swap parameters
        uint256 outputDesired = 0.1e18;
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(tokenA);

        // Calculate required input amount
        uint256[] memory expectedAmounts = router.getAmountsIn(outputDesired, path);
        uint256 maxETH = 1 ether;

        // Verify we have enough ETH for the swap
        uint256 ethBalanceBefore = alice.balance;
        require(ethBalanceBefore >= maxETH, "Insufficient ETH for test");

        uint256 tokenBalanceBefore = tokenA.balanceOf(alice);

        // Execute swap
        uint256[] memory amounts = router.swapETHForExactTokens{value: maxETH}(
            outputDesired,
            path,
            alice,
            deadline
        );

        uint256 ethBalanceAfter = alice.balance;
        uint256 tokenBalanceAfter = tokenA.balanceOf(alice);

        vm.stopPrank();

        // Verify results
        assertEq(amounts[1], outputDesired, "Incorrect output amount");
        assertLt(amounts[0], maxETH, "Input exceeds maximum");
        assertEq(amounts[0], expectedAmounts[0], "Input different from expected");
        assertEq(tokenBalanceAfter - tokenBalanceBefore, outputDesired, "Incorrect token balance change");
        assertEq(ethBalanceBefore - ethBalanceAfter, amounts[0], "Incorrect ETH spent");
    }

    function testSwapExactTokensForETH() public {
        vm.startPrank(alice);

        // Add initial liquidity to WETH/TokenA pair
        tokenA.approve(address(router), INITIAL_LIQUIDITY);
        router.addLiquidityETH{value: INITIAL_LIQUIDITY}(
            address(tokenA),
            INITIAL_LIQUIDITY,
            0,
            0,
            alice,
            deadline
        );

        // Setup swap parameters
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(weth);

        // Calculate expected amounts
        uint256[] memory expectedAmounts = router.getAmountsOut(SWAP_AMOUNT, path);

        // Approve tokens
        tokenA.approve(address(router), SWAP_AMOUNT);
        uint256 ethBalanceBefore = alice.balance;

        // Execute swap
        uint256[] memory amounts = router.swapExactTokensForETH(
            SWAP_AMOUNT,
            expectedAmounts[1], // Use expected amount as minimum output
            path,
            alice,
            deadline
        );

        uint256 ethBalanceAfter = alice.balance;

        vm.stopPrank();

        // Verify results
        assertEq(amounts[0], SWAP_AMOUNT, "Incorrect input amount");
        assertEq(amounts[1], expectedAmounts[1], "Output different from expected");
        assertEq(ethBalanceAfter - ethBalanceBefore, amounts[1], "Incorrect ETH received");
    }

    function testSwapTokensForExactETH() public {
        vm.startPrank(alice);

        // Add initial liquidity to WETH/TokenA pair
        tokenA.approve(address(router), INITIAL_LIQUIDITY);
        router.addLiquidityETH{value: INITIAL_LIQUIDITY}(
            address(tokenA),
            INITIAL_LIQUIDITY,
            0,
            0,
            alice,
            deadline
        );

        // Setup swap parameters
        uint256 ethOutputDesired = 0.1 ether;
        uint256 maxTokens = 1e18;
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(weth);

        // Calculate expected amounts
        uint256[] memory expectedAmounts = router.getAmountsIn(ethOutputDesired, path);

        // Approve tokens
        tokenA.approve(address(router), expectedAmounts[0]);
        uint256 ethBalanceBefore = alice.balance;
        uint256 tokenBalanceBefore = tokenA.balanceOf(alice);

        // Execute swap
        uint256[] memory amounts = router.swapTokensForExactETH(
            ethOutputDesired,
            maxTokens,
            path,
            alice,
            deadline
        );

        uint256 ethBalanceAfter = alice.balance;
        uint256 tokenBalanceAfter = tokenA.balanceOf(alice);

        vm.stopPrank();

        // Verify results
        assertEq(amounts[1], ethOutputDesired, "Incorrect ETH output");
        assertLt(amounts[0], maxTokens, "Input exceeds maximum");
        assertEq(amounts[0], expectedAmounts[0], "Input different from expected");
        assertEq(tokenBalanceBefore - tokenBalanceAfter, amounts[0], "Incorrect token spent");
        assertEq(ethBalanceAfter - ethBalanceBefore, ethOutputDesired, "Incorrect ETH received");
    }

}

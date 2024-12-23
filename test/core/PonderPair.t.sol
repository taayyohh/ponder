// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../src/core/PonderPair.sol";
import "../../src/core/PonderToken.sol";
import "../../src/launch/LaunchToken.sol";
import "../../src/periphery/PonderRouter.sol";
import "../mocks/ERC20Mint.sol";
import "../mocks/WETH9.sol";
import "forge-std/Test.sol";

contract MockKKUBUnwrapper {
    address public immutable WETH;

    constructor(address _weth) {
        WETH = _weth;
    }

    function unwrapKKUB(uint256 amount, address recipient) external returns (bool) {
        // Transfer WETH from sender to this contract
        require(IERC20(WETH).transferFrom(msg.sender, address(this), amount), "Transfer failed");
        // Unwrap WETH for ETH
        IWETH(WETH).withdraw(amount);
        // Send ETH to recipient
        (bool success,) = recipient.call{value: amount}("");
        require(success, "ETH transfer failed");
        return true;
    }

    receive() external payable {}
}

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

    // Add getPair function that router needs
    function getPair(address tokenA, address tokenB) external view returns (address) {
        return pairs[tokenA][tokenB];
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
    MockKKUBUnwrapper unwrapper; // Add unwrapper
    PonderRouter router; // Add router variable


    // Users for testing
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address creator = makeAddr("creator");
    address treasury = makeAddr("treasury");
    address ponderLauncher = makeAddr("ponderLaunchefr"); // New: separate launcher for PONDER

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
        // Changed: Use separate launcher for PONDER
        ponder = new PonderToken(treasury, treasury, treasury, ponderLauncher);

        // Set up mock factory - uses test contract as launcher for launch tokens
        factory = new MockFactory(bob, address(this), address(ponder));

        // Setup unwrapper and router
        unwrapper = new MockKKUBUnwrapper(address(weth));
        router = new PonderRouter(
            address(factory),
            address(weth),
            address(unwrapper)
        );

        // Deploy LaunchToken - uses factory's launcher (address(this))
        launchToken = new LaunchToken(
            "Launch Token",
            "LAUNCH",
            address(this),  // This matches factory's launcher
            address(factory),
            payable(address(1)),
            address(ponder)
        );

        // Rest of setup remains the same...
        launchToken.setupVesting(creator, INITIAL_LIQUIDITY_AMOUNT);
        launchToken.enableTransfers();

        address standardPairAddr = factory.createPair(address(token0), address(token1));
        address kubPairAddr = factory.createPair(address(launchToken), address(weth));
        address ponderPairAddr = factory.createPair(address(launchToken), address(ponder));

        standardPair = PonderPair(standardPairAddr);
        kubPair = PonderPair(kubPairAddr);
        ponderPair = PonderPair(ponderPairAddr);

        launchToken.setPairs(kubPairAddr, ponderPairAddr);

        token0.mint(alice, INITIAL_LIQUIDITY_AMOUNT * 2);
        token1.mint(alice, INITIAL_LIQUIDITY_AMOUNT * 2);
        deal(address(launchToken), alice, INITIAL_LIQUIDITY_AMOUNT * 2);
        deal(address(weth), alice, INITIAL_LIQUIDITY_AMOUNT * 2);
        deal(address(ponder), alice, INITIAL_LIQUIDITY_AMOUNT * 2);

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

        console.log("Standard swap:");
        console.log("token0 address:", address(token0));
        console.log("token1 address:", address(token1));
        console.log("Pair token0:", standardPair.token0());
        console.log("Pair token1:", standardPair.token1());

        assertGt(token1.balanceOf(alice), 0, "Should have received token1");
        (uint112 reserve0, uint112 reserve1,) = standardPair.getReserves();
        assertGt(reserve0, INITIAL_LIQUIDITY_AMOUNT, "Reserve0 should have increased");
        assertLt(reserve1, INITIAL_LIQUIDITY_AMOUNT, "Reserve1 should have decreased");
    }

    function testKubPairFees() public {
        addInitialLiquidity(kubPair, launchToken, IERC20(address(weth)), INITIAL_LIQUIDITY_AMOUNT);

        uint256 creatorBalanceBefore = launchToken.balanceOf(creator);
        uint256 protocolBalanceBefore = launchToken.balanceOf(bob);

        vm.startPrank(alice);
        launchToken.transfer(address(kubPair), SWAP_AMOUNT);
        kubPair.swap(0, 900e18, alice, "");
        vm.stopPrank();

        // Calculate fees from original amount
        uint256 expectedProtocolFee = (SWAP_AMOUNT * 20) / 10000;  // 0.2% of original
        uint256 expectedCreatorFee = (SWAP_AMOUNT * 10) / 10000;   // 0.1% of original

        assertEq(
            launchToken.balanceOf(creator) - creatorBalanceBefore,
            expectedCreatorFee,
            "Incorrect creator fee for KUB pair"
        );
        assertEq(
            launchToken.balanceOf(bob) - protocolBalanceBefore,
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

    function testDetailedFeeCalculations() public {
        // Create standard pair first
        address standardPair = factory.createPair(address(token0), address(token1));
        PonderPair standardPairContract = PonderPair(standardPair);

        // Deploy launch token
        LaunchToken launchToken = new LaunchToken(
            "Test Token",
            "TEST",
            address(this),
            address(factory),
            payable(address(1)),
            address(ponder)
        );

        // Create pairs and set them
        address launchKubPair = factory.createPair(address(launchToken), address(weth));
        address launchPonderPair = factory.createPair(address(launchToken), address(ponder));

        // Setup launch token
        launchToken.setupVesting(creator, 1000e18);
        launchToken.setPairs(launchKubPair, launchPonderPair);
        launchToken.enableTransfers();

        uint256 swapAmount = SWAP_AMOUNT;
        uint256 FEE_DENOMINATOR = 10000;

        // Test PONDER pair fees
        {
            // Give fresh allocation for PONDER pair testing and setup properly
            deal(address(launchToken), alice, swapAmount * 2);
            ponder.setMinter(address(this));  // Set minter
            ponder.mint(alice, swapAmount * 2);  // Mint PONDER directly

            vm.startPrank(alice);
            ponder.approve(launchPonderPair, type(uint256).max);  // Approve PONDER spending

            // Add initial liquidity
            launchToken.transfer(launchPonderPair, swapAmount);
            ponder.transfer(launchPonderPair, swapAmount);
            PonderPair(launchPonderPair).mint(alice);

            // Record balances before swap
            uint256 creatorBalanceBefore = launchToken.balanceOf(creator);
            uint256 feeCollectorBalanceBefore = launchToken.balanceOf(bob);

            // Perform swap
            launchToken.transfer(launchPonderPair, swapAmount);
            PonderPair(launchPonderPair).swap(0, swapAmount / 2, alice, "");

            // Each fee is calculated from original amount
            uint256 expectedProtocolFee = (swapAmount * 15) / FEE_DENOMINATOR;  // 0.15% of original
            uint256 expectedCreatorFee = (swapAmount * 15) / FEE_DENOMINATOR;   // 0.15% of original

            assertEq(
                launchToken.balanceOf(creator) - creatorBalanceBefore,
                expectedCreatorFee,
                "Incorrect creator fee for PONDER pair"
            );
            assertEq(
                launchToken.balanceOf(bob) - feeCollectorBalanceBefore,
                expectedProtocolFee,
                "Incorrect protocol fee for PONDER pair"
            );

            vm.stopPrank();
        }

        // Test KUB pair fees
        {
            // Give fresh allocation
            deal(address(launchToken), alice, swapAmount * 2);
            deal(address(weth), alice, swapAmount * 2);

            vm.startPrank(alice);

            // Add initial liquidity
            launchToken.transfer(launchKubPair, swapAmount);
            weth.transfer(launchKubPair, swapAmount);
            PonderPair(launchKubPair).mint(alice);

            // Record balances before swap
            uint256 creatorBalanceBefore = launchToken.balanceOf(creator);
            uint256 feeCollectorBalanceBefore = launchToken.balanceOf(bob);

            // Perform swap
            launchToken.transfer(launchKubPair, swapAmount);
            PonderPair(launchKubPair).swap(0, swapAmount / 2, alice, "");

            // Each fee calculated from original amount
            uint256 expectedProtocolFee = (swapAmount * 20) / FEE_DENOMINATOR;  // 0.2% of original
            uint256 expectedCreatorFee = (swapAmount * 10) / FEE_DENOMINATOR;   // 0.1% of original

            assertEq(
                launchToken.balanceOf(creator) - creatorBalanceBefore,
                expectedCreatorFee,
                "Incorrect creator fee for KUB pair"
            );
            assertEq(
                launchToken.balanceOf(bob) - feeCollectorBalanceBefore,
                expectedProtocolFee,
                "Incorrect protocol fee for KUB pair"
            );

            vm.stopPrank();
        }

        // Test standard pair fees - this part stays the same
        {
            vm.warp(block.timestamp + 1);

            // Fresh allocation for standard pair
            deal(address(token0), alice, swapAmount * 2);
            deal(address(token1), alice, swapAmount * 2);

            vm.startPrank(alice);
            token0.transfer(standardPair, swapAmount);
            token1.transfer(standardPair, swapAmount);
            standardPairContract.mint(alice);

            // Record balance before standard swap
            uint256 standardFeeCollectorBefore = token0.balanceOf(bob);

            // Perform swap
            token0.transfer(standardPair, swapAmount);
            standardPairContract.swap(0, swapAmount / 2, alice, "");

            // Standard 0.3% protocol fee
            uint256 expectedProtocolFee = (swapAmount * 30) / FEE_DENOMINATOR;
            assertEq(
                token0.balanceOf(bob) - standardFeeCollectorBefore,
                expectedProtocolFee,
                "Incorrect protocol fee for standard pair"
            );

            vm.stopPrank();
        }
    }

    function testKValueValidation() public {
        // Setup pair with initial liquidity
        uint256 initialLiquidity = addInitialLiquidity(
            standardPair,
            token0,
            token1,
            INITIAL_LIQUIDITY_AMOUNT
        );

        // Get initial K value
        (uint112 reserve0, uint112 reserve1,) = standardPair.getReserves();
        uint256 initialK = uint256(reserve0) * uint256(reserve1);

        // Perform actual swap
        vm.startPrank(alice);
        token0.transfer(address(standardPair), SWAP_AMOUNT);
        standardPair.swap(0, SWAP_AMOUNT/2, alice, "");
        vm.stopPrank();

        // Check K value hasn't decreased
        (reserve0, reserve1,) = standardPair.getReserves();
        uint256 newK = uint256(reserve0) * uint256(reserve1);
        assertGe(newK, initialK, "K value should not decrease");
    }

    function testActualSwapWithFees() public {
        // Test with launch token and KUB pair since it has special fee logic
        addInitialLiquidity(
            kubPair,
            IERC20(address(launchToken)),
            IERC20(address(weth)),
            INITIAL_LIQUIDITY_AMOUNT
        );

        uint256 aliceWethBefore = weth.balanceOf(alice);
        uint256 protocolBalanceBefore = launchToken.balanceOf(bob); // bob is feeTo
        uint256 creatorBalanceBefore = launchToken.balanceOf(creator);

        // Perform swap
        vm.startPrank(alice);
        launchToken.transfer(address(kubPair), SWAP_AMOUNT);
        kubPair.swap(0, SWAP_AMOUNT/2, alice, "");
        vm.stopPrank();

        // Verify swap succeeded and fees were taken
        assertGt(weth.balanceOf(alice), aliceWethBefore, "Should have received WETH");
        assertGt(
            launchToken.balanceOf(bob) - protocolBalanceBefore,
            0,
            "Protocol should have received fees"
        );
        assertGt(
            launchToken.balanceOf(creator) - creatorBalanceBefore,
            0,
            "Creator should have received fees"
        );
    }

    function testFuzz_KValueMaintained(uint256 swapAmount) public {
        // Bound swap amount to reasonable values
        swapAmount = bound(
            swapAmount,
            INITIAL_LIQUIDITY_AMOUNT / 100,  // 1% of liquidity
            INITIAL_LIQUIDITY_AMOUNT / 2     // 50% of liquidity
        );

        // Add initial liquidity to standard pair
        addInitialLiquidity(
            standardPair,
            token0,
            token1,
            INITIAL_LIQUIDITY_AMOUNT
        );

        // Store initial reserves
        (uint112 initialReserve0, uint112 initialReserve1,) = standardPair.getReserves();
        uint256 initialK = uint256(initialReserve0) * uint256(initialReserve1);

        // Ensure alice has enough tokens
        token0.mint(alice, swapAmount);

        // Perform swap with fuzzed amount
        vm.startPrank(alice);
        token0.transfer(address(standardPair), swapAmount);
        standardPair.swap(0, swapAmount/2, alice, "");
        vm.stopPrank();

        // Get final reserves
        (uint112 finalReserve0, uint112 finalReserve1,) = standardPair.getReserves();
        uint256 finalK = uint256(finalReserve0) * uint256(finalReserve1);

        // Verify K value hasn't decreased
        assertGe(finalK, initialK, "K should never decrease");

        // Additional validations
        assertGt(token1.balanceOf(alice), 0, "Should have received tokens");
        assertGt(finalReserve0, initialReserve0, "Reserve0 should have increased");
        assertLt(finalReserve1, initialReserve1, "Reserve1 should have decreased");
    }

    function testPonderToTokenSwaps() public {
        // Create pair
        address ponderToken0Pair = factory.createPair(address(ponder), address(token0));
        PonderPair pair = PonderPair(ponderToken0Pair);

        vm.startPrank(alice);

        // Add liquidity
        ponder.transfer(address(pair), INITIAL_LIQUIDITY_AMOUNT);
        token0.transfer(address(pair), INITIAL_LIQUIDITY_AMOUNT);
        pair.mint(alice);

        // Approve tokens
        ponder.approve(address(router), type(uint256).max);
        token0.approve(address(router), type(uint256).max);

        // Record state
        uint256 token0BalanceBefore = token0.balanceOf(alice);
        uint256 feeToBefore = ponder.balanceOf(bob);

        // Set up path for "I want to swap PONDER for token0"
        address[] memory path = new address[](2);
        path[0] = address(ponder);  // Input token
        path[1] = address(token0);  // Output token

        // Execute swap
        router.swapExactTokensForTokens(
            SWAP_AMOUNT,
            0,
            path,
            alice,
            block.timestamp + 1
        );

        // Verify results
        assertGt(
            token0.balanceOf(alice) - token0BalanceBefore,
            0,
            "Should receive token0"
        );

        vm.stopPrank();
    }

    function testPonderToETHSwap() public {
        // Create PONDER/WETH pair
        address ponderKubPair = factory.createPair(address(ponder), address(weth));

        vm.startPrank(alice);
        // Add liquidity
        ponder.transfer(address(ponderKubPair), INITIAL_LIQUIDITY_AMOUNT);
        vm.deal(alice, INITIAL_LIQUIDITY_AMOUNT);
        weth.deposit{value: INITIAL_LIQUIDITY_AMOUNT}();
        weth.transfer(address(ponderKubPair), INITIAL_LIQUIDITY_AMOUNT);
        PonderPair(ponderKubPair).mint(alice);

        // Approve PONDER for router
        ponder.approve(address(router), type(uint256).max);

        // Record balances
        uint256 feeToBefore = ponder.balanceOf(bob);
        uint256 ethBalanceBefore = alice.balance;

        // Setup swap path
        address[] memory path = new address[](2);
        path[0] = address(ponder);
        path[1] = address(weth);

        // Execute swap
        router.swapExactTokensForETH(
            SWAP_AMOUNT,
            0, // no minimum for test
            path,
            alice,
            block.timestamp + 1
        );

        assertGt(
            alice.balance - ethBalanceBefore,
            0,
            "Should receive ETH"
        );
        assertEq(
            ponder.balanceOf(bob) - feeToBefore,
            (SWAP_AMOUNT * 30) / 10000,
            "Should take standard 0.3% fee when selling PONDER to ETH"
        );

        vm.stopPrank();
    }

    function testETHToLaunchTokenSwap() public {
        // Create launch token/WETH pair
        address launchKubPair = factory.createPair(address(launchToken), address(weth));

        // Fund alice
        vm.deal(alice, INITIAL_LIQUIDITY_AMOUNT * 2);

        // Add liquidity
        vm.startPrank(alice);

        // Add WETH side
        weth.deposit{value: INITIAL_LIQUIDITY_AMOUNT}();
        weth.transfer(address(launchKubPair), INITIAL_LIQUIDITY_AMOUNT);

        // Add launch token side
        launchToken.transfer(address(launchKubPair), INITIAL_LIQUIDITY_AMOUNT);
        PonderPair(launchKubPair).mint(alice);

        // Try swap
        uint256 swapAmount = 1 ether;
        vm.deal(alice, swapAmount); // Ensure alice has ETH to swap

        // This should fail like prod
        weth.deposit{value: swapAmount}();
        weth.transfer(address(launchKubPair), swapAmount);
        PonderPair(launchKubPair).swap(SWAP_AMOUNT/2, 0, alice, "");

        vm.stopPrank();
    }

    function testETHToLaunchTokenViaRouter() public {
        // Create launch token/WETH pair
        address launchKubPair = factory.createPair(address(launchToken), address(weth));

        // Fund alice
        vm.deal(alice, INITIAL_LIQUIDITY_AMOUNT * 2);

        vm.startPrank(alice);

        // Approve tokens for router
        launchToken.approve(address(router), type(uint256).max);
        weth.approve(address(router), type(uint256).max);

        // Add liquidity with ETH
        router.addLiquidityETH{value: INITIAL_LIQUIDITY_AMOUNT}(
            address(launchToken),
            INITIAL_LIQUIDITY_AMOUNT,
            0,
            0,
            alice,
            block.timestamp + 1
        );

        // Try swap
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(launchToken);

        router.swapExactETHForTokens{value: 1 ether}(
            0,
            path,
            alice,
            block.timestamp + 1
        );


        vm.stopPrank();
    }}

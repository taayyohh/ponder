// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../mocks/ERC20Mint.sol";
import "../../src/core/PonderFactory.sol";
import "../../src/core/PonderPair.sol";
import "../../src/core/PonderPriceOracle.sol";

contract PonderPriceOracleTest is Test {
    PonderFactory factory;
    PonderPriceOracle oracle;
    ERC20Mint ponder;
    ERC20Mint kub;
    ERC20Mint usdt;
    PonderPair ponderKubPair;
    PonderPair kubUsdtPair;
    ERC20Mint token0;
    ERC20Mint token1;
    PonderPair testPair;

    address alice = makeAddr("alice");

    uint256 constant INITIAL_LIQUIDITY = 100e18;
    uint256 constant USDT_LIQUIDITY = 100_000e6; // USDT has 6 decimals
    uint256 constant TIME_DELAY = 1 hours;
    uint256 constant MIN_UPDATE_DELAY = 5 minutes;

    function setUp() public {
        // Deploy factory and tokens
        factory = new PonderFactory(address(this), address(1));
        ponder = new ERC20Mint("Ponder", "PONDER");
        kub = new ERC20Mint("KUB", "KUB");
        usdt = new ERC20Mint("USDT", "USDT");
        token0 = new ERC20Mint("Token A", "TKNA");
        token1 = new ERC20Mint("Token B", "TKNB");

        // Create pairs
        address ponderKubAddress = factory.createPair(address(ponder), address(kub));
        ponderKubPair = PonderPair(ponderKubAddress);

        address kubUsdtAddress = factory.createPair(address(kub), address(usdt));
        kubUsdtPair = PonderPair(kubUsdtAddress);

        address testPairAddress = factory.createPair(address(token0), address(token1));
        testPair = PonderPair(testPairAddress);

        // Add liquidity to all pairs
        _addLiquidity();

        // Deploy oracle with USDT path
        oracle = new PonderPriceOracle(
            address(factory),
            address(ponderKubPair),
            address(usdt)
        );

        vm.warp(block.timestamp + MIN_UPDATE_DELAY);
    }

    function _addLiquidity() private {
        vm.startPrank(alice);

        // PONDER/KUB pair
        ponder.mint(alice, INITIAL_LIQUIDITY);
        kub.mint(alice, INITIAL_LIQUIDITY);
        ponder.transfer(address(ponderKubPair), INITIAL_LIQUIDITY);
        kub.transfer(address(ponderKubPair), INITIAL_LIQUIDITY);
        ponderKubPair.mint(alice);

        // KUB/USDT pair
        kub.mint(alice, INITIAL_LIQUIDITY);
        usdt.mint(alice, USDT_LIQUIDITY);
        kub.transfer(address(kubUsdtPair), INITIAL_LIQUIDITY);
        usdt.transfer(address(kubUsdtPair), USDT_LIQUIDITY);
        kubUsdtPair.mint(alice);

        // Test pair
        token0.mint(alice, INITIAL_LIQUIDITY);
        token1.mint(alice, INITIAL_LIQUIDITY);
        token0.transfer(address(testPair), INITIAL_LIQUIDITY);
        token1.transfer(address(testPair), INITIAL_LIQUIDITY);
        testPair.mint(alice);

        vm.stopPrank();
    }

    function testSpotPriceFallback() public {
        // Should get spot price without any observations
        (uint256 price, bool usedReserves) = oracle.getPrice(
            address(testPair),
            address(token0),
            1e18
        );
        assertTrue(usedReserves, "Should use reserves for first price");
        assertGt(price, 0, "Should return valid spot price");
    }

    function testUSDPricing() public {
        // Test USD price path through KUB
        (uint256 ponderPriceUSD, bool usedReserves) = oracle.getPriceInUSD(
            address(ponderKubPair),
            address(ponder),
            1e18
        );

        assertTrue(usedReserves, "Should use reserves initially");
        assertGt(ponderPriceUSD, 0, "Should return valid USD price");
    }

    function testTWAPvsFallback() public {
        // Initial update
        oracle.update(address(testPair));

        // Move time and make a trade
        vm.warp(block.timestamp + TIME_DELAY);
        _makeTradeOnPair(testPair, token0, 1e18);

        // Update after trade
        vm.warp(block.timestamp + MIN_UPDATE_DELAY);
        oracle.update(address(testPair));

        // Get both TWAP and spot price
        uint256 twapPrice = oracle.consult(
            address(testPair),
            address(token0),
            1e18,
            uint32(MIN_UPDATE_DELAY)
        );

        (uint256 spotPrice, bool usedReserves) = oracle.getPrice(
            address(testPair),
            address(token0),
            1e18
        );

        assertNotEq(twapPrice, spotPrice, "TWAP should differ from spot after trade");
    }

    function _makeTradeOnPair(PonderPair pair, ERC20Mint tokenIn, uint256 amount) private {
        vm.startPrank(alice);
        tokenIn.mint(alice, amount);
        tokenIn.transfer(address(pair), amount);

        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        uint256 expectedOutput = (amount * 997 * uint256(reserve1)) /
            (uint256(reserve0) * 1000 + (amount * 997));

        pair.swap(
            address(tokenIn) == pair.token0() ? 0 : expectedOutput,
            address(tokenIn) == pair.token0() ? expectedOutput : 0,
            alice,
            ""
        );
        vm.stopPrank();
    }

    function testPriceManipulationResistance() public {
        // Initial state
        oracle.update(address(testPair));
        vm.warp(block.timestamp + TIME_DELAY);

        // Get initial price
        (uint256 initialPrice,) = oracle.getPrice(
            address(testPair),
            address(token0),
            1e18
        );

        // Make a large trade to manipulate price
        _makeTradeOnPair(testPair, token0, INITIAL_LIQUIDITY * 10);

        // Get manipulated spot price
        (uint256 manipulatedPrice,) = oracle.getPrice(
            address(testPair),
            address(token0),
            1e18
        );

        // Update oracle and check TWAP
        vm.warp(block.timestamp + MIN_UPDATE_DELAY);
        oracle.update(address(testPair));

        uint256 twapPrice = oracle.consult(
            address(testPair),
            address(token0),
            1e18,
            uint32(MIN_UPDATE_DELAY)
        );

        // TWAP should be closer to initial price than manipulated price
        uint256 twapDiff = twapPrice > initialPrice ?
            twapPrice - initialPrice : initialPrice - twapPrice;
        uint256 spotDiff = manipulatedPrice > initialPrice ?
            manipulatedPrice - initialPrice : initialPrice - manipulatedPrice;

        assertTrue(twapDiff < spotDiff, "TWAP should be more stable than spot price");
    }

//    function testDifferentDecimals() public {
//        // Setup tokens with different decimals
//        ERC20Mint tokenSixDec = new ERC20Mint("Six", "SIX", 6);  // Like USDT
//        ERC20Mint tokenEightDec = new ERC20Mint("Eight", "EIGHT", 8);  // Like WBTC
//
//        // Create and initialize pair
//        address mixedPairAddr = factory.createPair(address(tokenSixDec), address(tokenEightDec));
//        PonderPair mixedPair = PonderPair(mixedPairAddr);
//
//        // Add liquidity considering decimal differences
//        vm.startPrank(alice);
//        tokenSixDec.mint(alice, 1000_000 * 1e6);  // 1M units with 6 decimals
//        tokenEightDec.mint(alice, 1000 * 1e8);    // 1K units with 8 decimals
//        tokenSixDec.transfer(address(mixedPair), 1000_000 * 1e6);
//        tokenEightDec.transfer(address(mixedPair), 1000 * 1e8);
//        mixedPair.mint(alice);
//        vm.stopPrank();
//
//        // Get price
//        (uint256 price, bool usedReserves) = oracle.getPrice(
//            address(mixedPair),
//            address(tokenSixDec),
//            1e6  // 1 unit of 6 decimal token
//        );
//
//        // Price should be properly normalized
//        assertTrue(price > 0, "Price should be non-zero");
//        // The price should reflect the 1000:1 ratio with proper decimal normalization
//        assertApproxEqRel(
//            price,
//            0.001 * 1e8,  // Expected price in 8 decimal token
//            0.01e18       // 1% tolerance
//        );
//    }
}

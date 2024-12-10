// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/libraries/PonderLaunchGuard.sol";
import "../../src/core/PonderFactory.sol";
import "../../src/core/PonderPair.sol";
import "../../src/core/PonderPriceOracle.sol";
import "../mocks/ERC20Mint.sol";

contract PonderLaunchGuardTest is Test {
    PonderFactory factory;
    PonderPair pair;
    PonderPriceOracle oracle;
    ERC20Mint tokenA;
    ERC20Mint tokenB;
    ERC20Mint usdt;

    address alice = makeAddr("alice");
    uint256 constant MIN_LIQUIDITY = 1000 ether;
    uint256 constant MAX_LIQUIDITY = 5000 ether;

    function setUp() public {
        // Start at a fixed timestamp
        vm.warp(1000);

        // Deploy tokens with deterministic ordering
        tokenA = new ERC20Mint("Token A", "TKNA");
        tokenB = new ERC20Mint("Token B", "TKNB");
        if (address(tokenA) > address(tokenB)) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }
        usdt = new ERC20Mint("USDT", "USDT");

        // Deploy factory and create pair
        factory = new PonderFactory(address(this), address(this));
        address pairAddress = factory.createPair(address(tokenA), address(tokenB));
        pair = PonderPair(pairAddress);

        // Deploy oracle
        oracle = new PonderPriceOracle(
            address(factory),
            pairAddress,
            address(usdt)
        );

        // Set up initial liquidity (2x minimum)
        _setupInitialLiquidity(MIN_LIQUIDITY * 2);

        // Initialize oracle with price history
        _initializeOracleHistory();
    }

    function _setupInitialLiquidity(uint256 amount) internal {
        vm.startPrank(alice);
        tokenA.mint(alice, amount);
        tokenB.mint(alice, amount * 10); // 10:1 ratio
        tokenA.transfer(address(pair), amount);
        tokenB.transfer(address(pair), amount * 10);
        pair.mint(alice);
        vm.stopPrank();
    }

    function _initializeOracleHistory() internal {
        // Initial sync
        pair.sync();
        vm.warp(block.timestamp + 1 hours);
        oracle.update(address(pair));

        // Additional price points
        for (uint i = 0; i < 3; i++) {
            vm.warp(block.timestamp + 1 hours);
            pair.sync();
            oracle.update(address(pair));
        }
    }

    function _removeLiquidity() internal {
        vm.startPrank(alice);
        uint256 lpBalance = pair.balanceOf(alice);
        if (lpBalance > 0) {
            pair.transfer(address(pair), lpBalance);
            pair.burn(alice);
        }
        vm.stopPrank();
    }

    function testDynamicCapScaling() public {
        uint256[] memory levels = new uint256[](3);
        levels[0] = MIN_LIQUIDITY * 2;   // 2000 KUB
        levels[1] = MIN_LIQUIDITY * 10;  // 10000 KUB - Bigger gap
        levels[2] = MIN_LIQUIDITY * 20;  // 20000 KUB - Even bigger gap

        uint256 lastPercent = 0;

        for (uint i = 0; i < levels.length; i++) {
            // Reset state
            _removeLiquidity();

            // Setup new liquidity
            _setupInitialLiquidity(levels[i]);

            // Update oracle with multiple points
            for (uint j = 0; j < 3; j++) {
                vm.warp(block.timestamp + 30 minutes);
                pair.sync();
                oracle.update(address(pair));
            }

            // Small test contribution
            uint256 testAmount = levels[i] / 20;  // 5% of liquidity

            (uint256 maxPercent,) = PonderLaunchGuard.validatePonderContribution(
                address(pair),
                address(oracle),
                testAmount
            );

            if (i > 0) {
                assertGt(maxPercent, lastPercent, "Cap should increase with liquidity");
            }
            lastPercent = maxPercent;
        }
    }

    function testPriceOutdated() public {
        // Initialize oracle
        _initializeOracleHistory();

        // Initial timestamp check
        (,,uint256 lastTimestamp) = oracle.getLatestPrice(address(pair));
        assertGt(lastTimestamp, 0, "Oracle should be initialized");

        // Move time forward past staleness threshold (1 hour)
        vm.warp(block.timestamp + 2 hours);

        vm.expectRevert(PonderLaunchGuard.PriceOutdated.selector);
        PonderLaunchGuard.validatePonderContribution(
            address(pair),
            address(oracle),
            MIN_LIQUIDITY / 10
        );
    }

    function testPriceImpactLimit() public {
        uint256 largeContrib = MIN_LIQUIDITY * 2;

        vm.expectRevert(PonderLaunchGuard.ExcessivePriceImpact.selector);
        PonderLaunchGuard.validatePonderContribution(
            address(pair),
            address(oracle),
            largeContrib
        );
    }

    function testValidateContributionWithinCap() public {
        uint256 contribValue = MIN_LIQUIDITY / 20;

        (uint256 maxPonderPercent, uint256 actualCap) = PonderLaunchGuard.validatePonderContribution(
            address(pair),
            address(oracle),
            contribValue
        );

        assertGt(maxPonderPercent, 0);
        assertGt(actualCap, 0);
        assertLe(maxPonderPercent, 2000);
    }

    function testRevertInsufficientLiquidity() public {
        _removeLiquidity();

        vm.expectRevert(PonderLaunchGuard.InsufficientLiquidity.selector);
        PonderLaunchGuard.validatePonderContribution(
            address(pair),
            address(oracle),
            100 ether
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/libraries/PonderLaunchGuard.sol";
import "../../src/core/PonderFactory.sol";
import "../../src/core/PonderPair.sol";
import "../../src/core/PonderPriceOracle.sol";
import "../mocks/ERC20.sol";

contract PonderLaunchGuardTest is Test {
    using PonderLaunchGuard for *;

    PonderFactory factory;
    PonderPriceOracle oracle;
    ERC20 ponder;
    ERC20 weth;
    PonderPair pair;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    uint256 constant INITIAL_LIQUIDITY = 10000 ether;
    uint256 constant TARGET_RAISE = 5555 ether;

    function setUp() public {
        // Deploy tokens
        ponder = new ERC20("PONDER", "PONDER", 18);
        weth = new ERC20("WETH", "WETH", 18);

        // Deploy factory
        factory = new PonderFactory(address(this), address(this), address(2), address(3));

        // Create PONDER/WETH pair
        address pairAddress = factory.createPair(address(ponder), address(weth));
        pair = PonderPair(pairAddress);

        // Create oracle with WETH as base token
        oracle = new PonderPriceOracle(
            address(factory),
            address(weth),    // Use WETH as the base token
            address(0)        // No stablecoin needed for tests
        );

        // Add initial liquidity
        _setupInitialLiquidity();
        _initializeOracleHistory();
    }

    function testValidPonderContribution() public {
        // Use a smaller amount that won't cause price impact issues
        uint256 amount = 10 ether;

        PonderLaunchGuard.ValidationResult memory result = PonderLaunchGuard.validatePonderContribution(
            address(pair),
            address(oracle),
            amount
        );

        assertGt(result.kubValue, 0, "KUB value should be non-zero");
        assertLt(result.priceImpact, PonderLaunchGuard.MAX_PRICE_IMPACT, "Price impact should be within limits");
        assertGe(result.maxPonderPercent, PonderLaunchGuard.MIN_PONDER_PERCENT, "Ponder percent should be above minimum");
        assertLe(result.maxPonderPercent, PonderLaunchGuard.MAX_PONDER_PERCENT, "Ponder percent should be below maximum");
    }


    function testValidKubContribution() public {
        uint256 amount = 1000 ether;
        uint256 totalRaised = 2000 ether;

        uint256 accepted = PonderLaunchGuard.validateKubContribution(
            amount,
            totalRaised,
            TARGET_RAISE
        );

        assertGt(accepted, 0, "Should accept valid contribution");
        assertLe(accepted + totalRaised, TARGET_RAISE, "Total should not exceed target");
    }

    function testLargeKubContribution() public {
        uint256 amount = TARGET_RAISE * 2;
        uint256 totalRaised = 1000 ether;

        uint256 accepted = PonderLaunchGuard.validateKubContribution(
            amount,
            totalRaised,
            TARGET_RAISE
        );

        assertEq(accepted, TARGET_RAISE - totalRaised, "Should limit to remaining amount");
    }

    function testInsufficientLiquidity() public {
        // Remove liquidity
        vm.startPrank(alice);
        uint256 lpBalance = pair.balanceOf(alice);
        pair.transfer(address(pair), lpBalance);
        pair.burn(alice);
        vm.stopPrank();

        vm.expectRevert(PonderLaunchGuard.InsufficientLiquidity.selector);
        PonderLaunchGuard.validatePonderContribution(
            address(pair),
            address(oracle),
            100 ether
        );
    }

    function testExcessivePriceImpact() public {
        // Use an amount that will definitely cause excessive price impact
        uint256 largeAmount = INITIAL_LIQUIDITY * 100;

        vm.expectRevert(PonderLaunchGuard.ExcessivePriceImpact.selector);
        PonderLaunchGuard.validatePonderContribution(
            address(pair),
            address(oracle),
            largeAmount
        );
    }

    function testPonderCapScaling() public {
        // Use smaller, more reasonable increments
        uint256[] memory liquidityLevels = new uint256[](3);
        liquidityLevels[0] = PonderLaunchGuard.MIN_LIQUIDITY;
        liquidityLevels[1] = PonderLaunchGuard.MIN_LIQUIDITY * 2;
        liquidityLevels[2] = PonderLaunchGuard.MAX_LIQUIDITY;

        uint256 lastPercent = 0;

        for (uint i = 0; i < liquidityLevels.length; i++) {
            // Reset liquidity
            _removeLiquidity();
            _setupLiquidity(liquidityLevels[i]);
            _initializeOracleHistory();

            // Test with a small amount to avoid price impact issues
            PonderLaunchGuard.ValidationResult memory result = PonderLaunchGuard.validatePonderContribution(
                address(pair),
                address(oracle),
                1 ether
            );

            if (i > 0) {
                assertGt(result.maxPonderPercent, lastPercent, "Cap should increase with liquidity");
            }
            lastPercent = result.maxPonderPercent;
        }
    }

    function testAcceptablePonderAmount() public {
        uint256 currentKub = 1000 ether;
        uint256 currentPonderValue = 500 ether;
        uint256 maxPonderPercent = 2000; // 20%

        uint256 acceptable = PonderLaunchGuard.getAcceptablePonderAmount(
            TARGET_RAISE,
            currentKub,
            currentPonderValue,
            maxPonderPercent
        );

        assertGt(acceptable, 0, "Should allow more PONDER");
        assertLe(
            currentPonderValue + acceptable,
            (TARGET_RAISE * maxPonderPercent) / PonderLaunchGuard.BASIS_POINTS,
            "Should not exceed max percent"
        );
    }

    function _setupInitialLiquidity() internal {
        vm.startPrank(alice);
        ponder.mint(alice, INITIAL_LIQUIDITY);
        weth.mint(alice, INITIAL_LIQUIDITY);

        ponder.transfer(address(pair), INITIAL_LIQUIDITY);
        weth.transfer(address(pair), INITIAL_LIQUIDITY);

        pair.mint(alice);
        vm.stopPrank();
    }

    function _setupLiquidity(uint256 amount) internal {
        vm.startPrank(alice);
        ponder.mint(alice, amount);
        weth.mint(alice, amount);

        ponder.transfer(address(pair), amount);
        weth.transfer(address(pair), amount);

        pair.mint(alice);
        vm.stopPrank();
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

    function _initializeOracleHistory() internal {
        // Initial sync
        pair.sync();
        vm.warp(block.timestamp + 1 hours);
        oracle.update(address(pair));

        // Build price history
        for (uint i = 0; i < 3; i++) {
            vm.warp(block.timestamp + 1 hours);
            pair.sync();
            oracle.update(address(pair));
        }
    }

    receive() external payable {}
}

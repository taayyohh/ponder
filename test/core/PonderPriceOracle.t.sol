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
    PonderPair ponderKubPair;
    ERC20Mint token0;
    ERC20Mint token1;
    PonderPair testPair;

    address alice = makeAddr("alice");

    // Testing constants
    uint256 constant INITIAL_LIQUIDITY = 100e18;
    uint256 constant TIME_DELAY = 1 hours;
    uint256 constant MIN_UPDATE_INTERVAL = 5 minutes;

    event PriceUpdated(
        address indexed pair,
        uint256 price0Average,
        uint256 price1Average,
        uint256 timestamp
    );

    function uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function setUp() public {
        // Deploy factory
        factory = new PonderFactory(address(this), address(1));

        // Deploy test tokens
        ponder = new ERC20Mint("Ponder", "PONDER");
        kub = new ERC20Mint("KUB", "KUB");
        token0 = new ERC20Mint("Token A", "TKNA");
        token1 = new ERC20Mint("Token B", "TKNB");

        // Create PONDER/KUB pair
        address ponderKubAddress = factory.createPair(address(ponder), address(kub));
        ponderKubPair = PonderPair(ponderKubAddress);

        // Create test pair
        address testPairAddress = factory.createPair(address(token0), address(token1));
        testPair = PonderPair(testPairAddress);

        // Add initial liquidity to PONDER/KUB pair
        vm.startPrank(alice);
        ponder.mint(alice, INITIAL_LIQUIDITY);
        kub.mint(alice, INITIAL_LIQUIDITY);
        ponder.transfer(address(ponderKubPair), INITIAL_LIQUIDITY);
        kub.transfer(address(ponderKubPair), INITIAL_LIQUIDITY);
        ponderKubPair.mint(alice);

        // Add initial liquidity to test pair
        token0.mint(alice, INITIAL_LIQUIDITY);
        token1.mint(alice, INITIAL_LIQUIDITY);
        token0.transfer(address(testPair), INITIAL_LIQUIDITY);
        token1.transfer(address(testPair), INITIAL_LIQUIDITY);
        testPair.mint(alice);
        vm.stopPrank();

        // Deploy oracle with PONDER/KUB pair
        oracle = new PonderPriceOracle(address(factory), address(ponderKubPair));

        // Move time forward for initialization
        vm.warp(block.timestamp + MIN_UPDATE_INTERVAL);
    }

    function testGetLatestPrice() public {
        // First update
        uint256 firstUpdateTime = block.timestamp;
        oracle.update(address(testPair));

        // Move time forward and make a trade
        vm.warp(block.timestamp + TIME_DELAY);
        vm.startPrank(alice);
        uint256 tradeAmount = 1e18; // Small trade amount
        token0.mint(alice, tradeAmount);
        token0.transfer(address(testPair), tradeAmount);

        (uint112 reserve0, uint112 reserve1,) = testPair.getReserves();
        uint256 expectedOutput = (tradeAmount * 997 * uint256(reserve1)) /
            (uint256(reserve0) * 1000 + (tradeAmount * 997));
        testPair.swap(0, expectedOutput, alice, "");
        vm.stopPrank();

        // Update oracle after trade
        vm.warp(block.timestamp + MIN_UPDATE_INTERVAL);
        uint256 secondUpdateTime = block.timestamp;
        oracle.update(address(testPair));

        // Get latest price
        (uint256 price0Average, uint256 price1Average, uint256 timestamp) =
                            oracle.getLatestPrice(address(testPair));

        assertGt(price0Average, 0, "Price0 average should be non-zero");
        assertGt(price1Average, 0, "Price1 average should be non-zero");
        assertTrue(
            timestamp <= block.timestamp && timestamp >= firstUpdateTime,
            string(abi.encodePacked(
                "Timestamp should be between first update and current time, got: ", uintToString(timestamp),
                ", first: ", uintToString(firstUpdateTime),
                ", current: ", uintToString(block.timestamp)
            ))
        );
    }

    function testConsultWithValidToken() public {
        // Initial update
        oracle.update(address(testPair));
        vm.warp(block.timestamp + TIME_DELAY);

        // Make a small trade to establish price
        vm.startPrank(alice);
        uint256 tradeAmount = 1e18;
        token0.mint(alice, tradeAmount);
        token0.transfer(address(testPair), tradeAmount);

        (uint112 reserve0, uint112 reserve1,) = testPair.getReserves();
        uint256 expectedOutput = (tradeAmount * 997 * uint256(reserve1)) /
            (uint256(reserve0) * 1000 + (tradeAmount * 997));
        testPair.swap(0, expectedOutput, alice, "");
        vm.stopPrank();

        // Second update after MIN_UPDATE_INTERVAL
        vm.warp(block.timestamp + MIN_UPDATE_INTERVAL);
        oracle.update(address(testPair));

        // Small time period and amount for consultation
        uint256 amountOut = oracle.consult(
            address(testPair),
            address(token0),
            1e15, // Much smaller amount
            uint32(MIN_UPDATE_INTERVAL)
        );

        assertGt(amountOut, 0, "Should return non-zero amount for valid token");
    }

    function testConsultInvalidToken() public {
        // Initial update
        oracle.update(address(testPair));
        vm.warp(block.timestamp + TIME_DELAY);

        // Update again to establish price data
        oracle.update(address(testPair));

        // Use non-pair token for consultation
        address randomToken = address(0xDEAD);
        vm.expectRevert(abi.encodeWithSignature("InvalidToken()"));
        oracle.consult(
            address(testPair),
            randomToken,
            1e18,
            uint32(TIME_DELAY)
        );
    }
}

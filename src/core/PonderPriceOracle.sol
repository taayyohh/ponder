// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IPonderPair.sol";
import "../interfaces/IPonderFactory.sol";
import "../libraries/PonderOracleLibrary.sol";

/// @title PonderPriceOracle
/// @notice Oracle for getting token prices from Ponder pairs with TWAP support
/// @dev Based on Uniswap V2 Oracle design with optimizations for meme token launches
contract PonderPriceOracle {
    struct Observation {
        uint32 timestamp;
        uint224 price0Cumulative;
        uint224 price1Cumulative;
    }

    uint16 public constant MAX_OBSERVATIONS = 60; // 5 hours with 5-min updates
    uint32 public constant PERIOD = 24 hours;
    uint32 public constant MIN_UPDATE_DELAY = 5 minutes;

    address public immutable factory;
    address public immutable ponderKubPair;
    address public immutable stablecoin;

    mapping(address => Observation[]) public observations;
    mapping(address => uint256) public currentIndex;
    mapping(address => uint256) public lastUpdateTime;

    error InvalidPair();
    error InvalidPeriod();
    error InsufficientHistory();
    error InvalidToken();
    error UpdateTooFrequent();
    error StalePrice();

    constructor(address _factory, address _ponderKubPair, address _stablecoin) {
        factory = _factory;
        ponderKubPair = _ponderKubPair;
        stablecoin = _stablecoin;
    }

    function update(address pair) external {
        if (block.timestamp < lastUpdateTime[pair] + MIN_UPDATE_DELAY) revert UpdateTooFrequent();
        if (!_isValidPair(pair)) revert InvalidPair();

        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) =
                            PonderOracleLibrary.currentCumulativePrices(pair);

        _updateObservations(pair, price0Cumulative, price1Cumulative);

        emit PriceUpdated(pair, price0Cumulative, price1Cumulative, blockTimestamp);
    }

    function getPrice(
        address pair,
        address tokenIn,
        uint256 amountIn
    ) external view returns (uint256 amountOut, bool usedReserves) {
        IPonderPair pairContract = IPonderPair(pair);
        (uint8 decimalsIn, uint8 decimalsOut) = _getDecimals(pairContract, tokenIn);

        // Try TWAP first
        if (lastUpdateTime[pair] > 0 && block.timestamp <= lastUpdateTime[pair] + PERIOD) {
            (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) =
                                PonderOracleLibrary.currentCumulativePrices(pair);

            (uint256 oldPrice0Cumulative, uint256 oldPrice1Cumulative, uint256 timestamp) =
                            _findClosestObservation(pair, blockTimestamp - 30 minutes);

            uint32 timeElapsed = blockTimestamp - uint32(timestamp);
            if (timeElapsed > 0) {
                bool isToken0 = tokenIn == pairContract.token0();
                return (
                    _calculateAmount(
                    isToken0 ? oldPrice0Cumulative : oldPrice1Cumulative,
                    isToken0 ? price0Cumulative : price1Cumulative,
                    timeElapsed,
                    amountIn,
                    decimalsIn,
                    decimalsOut
                ),
                    false
                );
            }
        }

        // Fall back to spot price
        return _getSpotPrice(pairContract, tokenIn, amountIn, decimalsIn, decimalsOut);
    }

    function getPriceInUSD(
        address pair,
        address tokenIn,
        uint256 amountIn
    ) external view returns (uint256 amountUSD, bool usedReserves) {
        address stablePair = IPonderFactory(factory).getPair(tokenIn, stablecoin);
        if (stablePair == address(0)) {
            return _getPriceViaKUB(pair, tokenIn, amountIn);
        }
        return this.getPrice(stablePair, tokenIn, amountIn);
    }

    function getLatestPrice(address pair) external view returns (
        uint256 price0,
        uint256 price1,
        uint256 timestamp
    ) {
        (uint112 reserve0, uint112 reserve1,) = IPonderPair(pair).getReserves();
        price0 = uint256(reserve1) * 1e18 / uint256(reserve0);
        price1 = uint256(reserve0) * 1e18 / uint256(reserve1);
        timestamp = block.timestamp;
    }

    function _updateObservations(
        address pair,
        uint256 price0Cumulative,
        uint256 price1Cumulative
    ) internal {
        Observation[] storage history = observations[pair];

        if (history.length == 0) {
            history.push(Observation({
                timestamp: uint32(block.timestamp),
                price0Cumulative: uint224(price0Cumulative),
                price1Cumulative: uint224(price1Cumulative)
            }));
            for (uint16 i = 1; i < MAX_OBSERVATIONS; i++) {
                history.push(history[0]);
            }
            currentIndex[pair] = 0;
        } else {
            uint256 index = (currentIndex[pair] + 1) % MAX_OBSERVATIONS;
            history[index] = Observation({
                timestamp: uint32(block.timestamp),
                price0Cumulative: uint224(price0Cumulative),
                price1Cumulative: uint224(price1Cumulative)
            });
            currentIndex[pair] = index;
        }

        lastUpdateTime[pair] = block.timestamp;
    }

    function _findClosestObservation(
        address pair,
        uint256 targetTimestamp
    ) internal view returns (uint256, uint256, uint256) {
        Observation[] storage history = observations[pair];
        uint256 currentIdx = currentIndex[pair];

        for (uint16 i = 0; i < MAX_OBSERVATIONS; i++) {
            uint256 index = (currentIdx + MAX_OBSERVATIONS - i) % MAX_OBSERVATIONS;
            if (history[index].timestamp <= targetTimestamp) {
                return (
                    history[index].price0Cumulative,
                    history[index].price1Cumulative,
                    history[index].timestamp
                );
            }
        }

        uint256 oldestIndex = (currentIdx + 1) % MAX_OBSERVATIONS;
        return (
            history[oldestIndex].price0Cumulative,
            history[oldestIndex].price1Cumulative,
            history[oldestIndex].timestamp
        );
    }

    function _calculateAmount(
        uint256 oldPrice,
        uint256 newPrice,
        uint32 timeElapsed,
        uint256 amountIn,
        uint8 decimalsIn,
        uint8 decimalsOut
    ) internal pure returns (uint256) {
        uint256 priceDiff = newPrice - oldPrice;
        uint256 priceAverage = (priceDiff * 1e18) / timeElapsed;
        uint256 scaledAmount = (amountIn * (10 ** decimalsOut)) / (10 ** decimalsIn);
        return (scaledAmount * priceAverage) / 1e18;
    }

    function _getSpotPrice(
        IPonderPair pairContract,
        address tokenIn,
        uint256 amountIn,
        uint8 decimalsIn,
        uint8 decimalsOut
    ) internal view returns (uint256, bool) {
        (uint112 reserve0, uint112 reserve1,) = pairContract.getReserves();
        if (tokenIn == pairContract.token0()) {
            return (
                uint256(reserve1) * amountIn * (10 ** decimalsOut) /
                (uint256(reserve0) * (10 ** decimalsIn)),
                true
            );
        } else {
            return (
                uint256(reserve0) * amountIn * (10 ** decimalsOut) /
                (uint256(reserve1) * (10 ** decimalsIn)),
                true
            );
        }
    }

    function _getPriceViaKUB(
        address pair,
        address tokenIn,
        uint256 amountIn
    ) internal view returns (uint256, bool) {
        address kubToken = IPonderPair(ponderKubPair).token1();
        address kubPair = IPonderFactory(factory).getPair(tokenIn, kubToken);
        if (kubPair == address(0)) return (0, true);

        (uint256 amountKub, bool usedReservesKub) = this.getPrice(kubPair, tokenIn, amountIn);
        address kubStablePair = IPonderFactory(factory).getPair(kubToken, stablecoin);
        if (kubStablePair == address(0)) return (0, true);

        (uint256 amountUSDFinal, bool usedReservesUSD) = this.getPrice(kubStablePair, kubToken, amountKub);
        return (amountUSDFinal, usedReservesKub || usedReservesUSD);
    }

    function _getDecimals(
        IPonderPair pairContract,
        address tokenIn
    ) internal view returns (uint8 decimalsIn, uint8 decimalsOut) {
        address token0 = pairContract.token0();
        if (tokenIn == token0) {
            decimalsIn = IERC20(token0).decimals();
            decimalsOut = IERC20(pairContract.token1()).decimals();
        } else {
            decimalsIn = IERC20(pairContract.token1()).decimals();
            decimalsOut = IERC20(token0).decimals();
        }
    }

    function _isValidPair(address pair) internal view returns (bool) {
        return IPonderFactory(factory).getPair(
            IPonderPair(pair).token0(),
            IPonderPair(pair).token1()
        ) == pair;
    }

    event PriceUpdated(
        address indexed pair,
        uint256 price0Cumulative,
        uint256 price1Cumulative,
        uint256 timestamp
    );
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IPonderPair.sol";
import "../interfaces/IPonderFactory.sol";
import "../libraries/PonderOracleLibrary.sol";

contract PonderPriceOracle {
    struct Observation {
        uint256 timestamp;
        uint256 price0Cumulative;
        uint256 price1Cumulative;
        uint256 price0Average;    // Added for quick TWAP access
        uint256 price1Average;    // Added for quick TWAP access
    }

    address public immutable factory;
    address public immutable ponderKubPair;  // Added for quick access to PONDER/KUB pair
    uint256 public constant PERIOD = 24 hours;
    uint256 public constant MIN_UPDATE_INTERVAL = 5 minutes;  // Added minimum update interval

    // Price observations mapped by pair address
    mapping(address => Observation[]) public observations;
    // Track last update time to prevent manipulation
    mapping(address => uint256) public lastUpdateTime;

    error InvalidPair();
    error InvalidPeriod();
    error InsufficientHistory();
    error InvalidToken();
    error UpdateTooFrequent();
    error StalePrice();

    event PriceUpdated(
        address indexed pair,
        uint256 price0Average,
        uint256 price1Average,
        uint256 timestamp
    );

    constructor(address _factory, address _ponderKubPair) {
        factory = _factory;
        ponderKubPair = _ponderKubPair;
    }

    function update(address pair) external {
        // Validate update frequency
        if (block.timestamp < lastUpdateTime[pair] + MIN_UPDATE_INTERVAL) {
            revert UpdateTooFrequent();
        }

        // Validate pair
        if (IPonderFactory(factory).getPair(
            IPonderPair(pair).token0(),
            IPonderPair(pair).token1()
        ) != pair) {
            revert InvalidPair();
        }

        // Get current prices
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) =
                            PonderOracleLibrary.currentCumulativePrices(pair);

        // Calculate TWAPs if we have previous observations
        Observation[] storage history = observations[pair];

        uint256 price0Average = 0;
        uint256 price1Average = 0;

        if (history.length > 0) {
            Observation storage lastObs = history[history.length - 1];
            uint256 timeElapsed = blockTimestamp - lastObs.timestamp;

            if (timeElapsed > 0) {
                price0Average = (price0Cumulative - lastObs.price0Cumulative) / timeElapsed;
                price1Average = (price1Cumulative - lastObs.price1Cumulative) / timeElapsed;
            }
        }

        // Store new observation
        observations[pair].push(Observation({
            timestamp: blockTimestamp,
            price0Cumulative: price0Cumulative,
            price1Cumulative: price1Cumulative,
            price0Average: price0Average,
            price1Average: price1Average
        }));

        lastUpdateTime[pair] = block.timestamp;

        emit PriceUpdated(pair, price0Average, price1Average, blockTimestamp);
    }

    function consult(
        address pair,
        address tokenIn,
        uint256 amountIn,
        uint32 periodInSeconds
    ) external view returns (uint256 amountOut) {
        if (periodInSeconds == 0 || periodInSeconds > PERIOD) revert InvalidPeriod();
        if (amountIn == 0) return 0;

        Observation[] storage history = observations[pair];
        if (history.length == 0) revert InsufficientHistory();

        // Check for stale prices
        if (block.timestamp > lastUpdateTime[pair] + PERIOD) {
            revert StalePrice();
        }

        // Get current cumulative prices and timestamp
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) =
                            PonderOracleLibrary.currentCumulativePrices(pair);

        // Find observation from periodInSeconds ago
        uint256 targetTimestamp = blockTimestamp - periodInSeconds;
        (uint256 oldPrice0Cumulative, uint256 oldPrice1Cumulative, uint256 oldTimestamp) =
                        _findObservation(pair, targetTimestamp);

        uint32 timeElapsed = blockTimestamp - uint32(oldTimestamp);
        require(timeElapsed > 0, "PonderPriceOracle: NO_TIME_ELAPSED");

        if (tokenIn == IPonderPair(pair).token0()) {
            return PonderOracleLibrary.computeAmountOut(
                oldPrice0Cumulative,
                price0Cumulative,
                timeElapsed,
                amountIn
            );
        } else if (tokenIn == IPonderPair(pair).token1()) {
            return PonderOracleLibrary.computeAmountOut(
                oldPrice1Cumulative,
                price1Cumulative,
                timeElapsed,
                amountIn
            );
        } else {
            revert InvalidToken();
        }
    }

    // Quick access function for PONDER/KUB price
    function getPonderKubPrice(uint32 periodInSeconds) external view returns (uint256) {
        return this.consult(
            ponderKubPair,
            IPonderPair(ponderKubPair).token1(), // KUB
            1e18,                                // 1 KUB
            periodInSeconds
        );
    }

    function _findObservation(
        address pair,
        uint256 targetTimestamp
    ) private view returns (
        uint256 price0Cumulative,
        uint256 price1Cumulative,
        uint256 timestamp
    ) {
        Observation[] storage observations_ = observations[pair];
        if (observations_.length == 0) revert InsufficientHistory();

        // If only one observation, return it
        if (observations_.length == 1) {
            Observation memory firstObs = observations_[0];
            return (
                firstObs.price0Cumulative,
                firstObs.price1Cumulative,
                firstObs.timestamp
            );
        }

        // Binary search for closest observation
        uint256 left = 0;
        uint256 right = observations_.length - 1;

        while (left < right) {
            uint256 mid = (left + right + 1) / 2;
            if (observations_[mid].timestamp <= targetTimestamp) {
                left = mid;
            } else {
                right = mid - 1;
            }
        }

        Observation memory observation = observations_[left];
        return (
            observation.price0Cumulative,
            observation.price1Cumulative,
            observation.timestamp
        );
    }

    // View functions for analysis
    function observationLength(address pair) external view returns (uint256) {
        return observations[pair].length;
    }

    function getLatestPrice(address pair) external view returns (
        uint256 price0Average,
        uint256 price1Average,
        uint256 timestamp
    ) {
        Observation[] storage history = observations[pair];
        if (history.length == 0) revert InsufficientHistory();

        Observation storage latest = history[history.length - 1];
        return (
            latest.price0Average,
            latest.price1Average,
            latest.timestamp
        );
    }
}

// src/core/PonderPriceOracle.sol
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
    }

    address public immutable factory;
    uint public constant PERIOD = 24 hours;

    // Price observations mapped by pair address
    mapping(address => Observation[]) public observations;

    error InvalidPair();
    error InvalidPeriod();
    error InsufficientHistory();
    error InvalidToken();

    constructor(address _factory) {
        factory = _factory;
    }

    // Update price accumulator for a pair
    function update(address pair) external {
        // Check if this is a valid pair from our factory
        if (IPonderFactory(factory).getPair(IPonderPair(pair).token0(), IPonderPair(pair).token1()) != pair) {
            revert InvalidPair();
        }

        // Get current prices
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) =
                            PonderOracleLibrary.currentCumulativePrices(pair);

        Observation memory observation = Observation({
            timestamp: blockTimestamp,
            price0Cumulative: price0Cumulative,
            price1Cumulative: price1Cumulative
        });

        observations[pair].push(observation);
    }

    // Get the TWAP price for a given time window
    // Part of PonderPriceOracle.sol - just the consult function
    function consult(
        address pair,
        address tokenIn,
        uint256 amountIn,
        uint32 periodInSeconds
    ) external view returns (uint256 amountOut) {
        if (periodInSeconds == 0 || periodInSeconds > PERIOD) revert InvalidPeriod();

        // Return early if amountIn is 0
        if (amountIn == 0) return 0;

        Observation[] storage history = observations[pair];
        if (history.length == 0) revert InsufficientHistory();

        // Get current cumulative prices and timestamp
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) =
                            PonderOracleLibrary.currentCumulativePrices(pair);

        // Find the observation from periodInSeconds ago
        uint256 targetTimestamp = blockTimestamp - periodInSeconds;

        // Binary search through observations
        (uint256 oldPrice0Cumulative, uint256 oldPrice1Cumulative, uint256 oldTimestamp) =
                        _findObservation(pair, targetTimestamp);

        // Ensure we have enough time elapsed
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

    // Binary search to find the observation closest to the target timestamp
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

    // Get the number of observations for a pair
    function observationLength(address pair) external view returns (uint256) {
        return observations[pair].length;
    }
}

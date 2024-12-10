// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IPonderPriceOracle {
    /// @notice Returns the latest cumulative price data for a pair
    /// @param pair The pair to get price data for
    /// @return price0Average Average price of token0 in token1
    /// @return price1Average Average price of token1 in token0
    /// @return timestamp Timestamp of the observation
    function getLatestPrice(address pair) external view returns (
        uint256 price0Average,
        uint256 price1Average,
        uint256 timestamp
    );

    /// @notice Consults the oracle for the value of one token in terms of another
    /// @param pair The pair to consult
    /// @param tokenIn The token being traded in
    /// @param amountIn The amount of tokenIn
    /// @param periodInSeconds The period over which to calculate TWAP
    /// @return amountOut The value in terms of the other token
    function consult(
        address pair,
        address tokenIn,
        uint256 amountIn,
        uint32 periodInSeconds
    ) external view returns (uint256 amountOut);

    /// @notice Updates price accumulator for a given pair
    /// @param pair The pair to update
    function update(address pair) external;

    /// @notice Event emitted when a price is updated
    event PriceUpdated(
        address indexed pair,
        uint256 price0Average,
        uint256 price1Average,
        uint256 timestamp
    );

    /// @notice Error thrown when a pair is invalid
    error InvalidPair();

    /// @notice Error thrown when period is invalid
    error InvalidPeriod();

    /// @notice Error thrown when there's insufficient price history
    error InsufficientHistory();

    /// @notice Error thrown when token is not part of the pair
    error InvalidToken();

    /// @notice Error thrown when price update is too frequent
    error UpdateTooFrequent();

    /// @notice Error thrown when price data is stale
    error StalePrice();
}

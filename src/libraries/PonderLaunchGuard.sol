// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IPonderPair.sol";
import "../interfaces/IPonderFactory.sol";
import "../interfaces/IPonderPriceOracle.sol";
import "../libraries/Math.sol";

/// @title PonderLaunchGuard
/// @notice Safety and validation library for Ponder launches
/// @dev Provides liquidity checks, contribution caps, and price impact protection
library PonderLaunchGuard {
    /// @notice Minimum liquidity required for full PONDER acceptance
    uint256 public constant MIN_LIQUIDITY_FULL = 5000 ether;  // 5000 KUB
    /// @notice Minimum liquidity required for any PONDER acceptance
    uint256 public constant MIN_LIQUIDITY_BASE = 1000 ether;  // 1000 KUB

    /// @notice Price impact limits in basis points (100 = 1%)
    uint256 public constant MAX_PRICE_IMPACT = 500;           // 5%
    uint256 public constant CRITICAL_PRICE_IMPACT = 1000;     // 10%

    /// @notice Contribution caps
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MIN_PONDER_CAP = 500;            // 5%
    uint256 public constant MAX_PONDER_CAP = 2000;           // 20%

    /// @notice Error codes
    error InsufficientLiquidity();
    error ExcessivePriceImpact();
    error ContributionTooLarge();
    error PriceOutdated();

    /// @notice Check if a PONDER contribution is safe based on pool liquidity
    /// @param ponderKubPair Address of the PONDER/KUB pair
    /// @param ponderOracle Address of the price oracle
    /// @param contribValue KUB value of the contribution
    /// @return maxPonderPercent Maximum percentage of PONDER allowed (in basis points)
    /// @return actualCap The KUB value cap for PONDER contributions
    function validatePonderContribution(
        address ponderKubPair,
        address ponderOracle,
        uint256 contribValue
    ) public view returns (uint256 maxPonderPercent, uint256 actualCap) {
        // Get current liquidity
        (uint112 ponderReserve, uint112 kubReserve,) = IPonderPair(ponderKubPair).getReserves();
        uint256 totalLiquidity = kubReserve * 2; // Consider both sides

        // Require minimum liquidity
        if (totalLiquidity < MIN_LIQUIDITY_BASE) {
            revert InsufficientLiquidity();
        }

        // Calculate dynamic cap based on liquidity
        maxPonderPercent = _calculatePonderCap(totalLiquidity);

        // Get latest price and check freshness
        IPonderPriceOracle oracle = IPonderPriceOracle(ponderOracle);
        (uint256 latestPrice,,uint256 timestamp) = oracle.getLatestPrice(ponderKubPair);
        if (block.timestamp > timestamp + 1 hours) {
            revert PriceOutdated();
        }

        // Calculate actual contribution cap
        actualCap = (contribValue * maxPonderPercent) / BASIS_POINTS;

        // Check price impact
        uint256 priceImpact = _calculatePriceImpact(ponderReserve, kubReserve, contribValue);
        if (priceImpact > MAX_PRICE_IMPACT) {
            revert ExcessivePriceImpact();
        }
    }

    /// @notice Calculate the maximum PONDER contribution percentage based on liquidity
    /// @param totalLiquidity Total liquidity in the PONDER/KUB pool
    /// @return cap The maximum percentage of PONDER allowed (in basis points)
    function _calculatePonderCap(uint256 totalLiquidity) internal pure returns (uint256 cap) {
        if (totalLiquidity >= MIN_LIQUIDITY_FULL) {
            return MAX_PONDER_CAP;
        }

        // Linear interpolation between min and max caps
        uint256 liquidityRange = MIN_LIQUIDITY_FULL - MIN_LIQUIDITY_BASE;
        uint256 capRange = MAX_PONDER_CAP - MIN_PONDER_CAP;
        uint256 liquidityAboveMin = totalLiquidity > MIN_LIQUIDITY_BASE ?
            totalLiquidity - MIN_LIQUIDITY_BASE : 0;

        // Adjust calculation to ensure cap increases with liquidity
        cap = MIN_PONDER_CAP + ((liquidityAboveMin * capRange) / liquidityRange);

        // Ensure cap stays within bounds
        if (cap > MAX_PONDER_CAP) {
            return MAX_PONDER_CAP;
        }
        return cap;
    }

    /// @notice Calculate the price impact of a contribution
    /// @param ponderReserve Current PONDER reserve
    /// @param kubReserve Current KUB reserve
    /// @param contribValue Size of contribution in KUB
    /// @return impact Price impact in basis points
    function _calculatePriceImpact(
        uint112 ponderReserve,
        uint112 kubReserve,
        uint256 contribValue
    ) internal pure returns (uint256 impact) {
        uint256 k = uint256(ponderReserve) * uint256(kubReserve);
        uint256 newKubReserve = uint256(kubReserve) + contribValue;
        uint256 newPonderReserve = k / newKubReserve;

        uint256 oldPrice = (uint256(kubReserve) * BASIS_POINTS) / uint256(ponderReserve);
        uint256 newPrice = (newKubReserve * BASIS_POINTS) / newPonderReserve;

        if (newPrice > oldPrice) {
            impact = ((newPrice - oldPrice) * BASIS_POINTS) / oldPrice;
        } else {
            impact = ((oldPrice - newPrice) * BASIS_POINTS) / oldPrice;
        }
    }
}

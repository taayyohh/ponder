// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IPonderPair.sol";
import "../interfaces/IPonderFactory.sol";
import "../interfaces/IPonderPriceOracle.sol";
import "../interfaces/IERC20.sol";

library PonderLaunchGuard {
    uint256 public constant TWAP_PERIOD = 24 hours;
    uint256 public constant PRICE_STALENESS_THRESHOLD = 1 hours;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MIN_LIQUIDITY = 1000 ether;
    uint256 public constant MAX_LIQUIDITY = 5000 ether;
    uint256 public constant MIN_PONDER_PERCENT = 500;   // 5%
    uint256 public constant MAX_PONDER_PERCENT = 2000;  // 20%
    uint256 public constant MAX_PRICE_IMPACT = 500;     // 5%
    uint256 public constant CRITICAL_PRICE_IMPACT = 1000; // 10%

    error InsufficientLiquidity();
    error ExcessivePriceImpact();
    error InvalidPrice();
    error StalePrice();
    error ContributionTooLarge();
    error ZeroAmount();

    struct ValidationResult {
        uint256 kubValue;          // Value in KUB terms
        uint256 priceImpact;       // Impact in basis points
        uint256 maxPonderPercent;  // Maximum PONDER acceptance
    }

    function validatePonderContribution(
        address pair,
        address oracle,
        uint256 amount
    ) external view returns (ValidationResult memory result) {
        if (amount == 0) revert ZeroAmount();

        // Get pair reserves
        (uint112 reserve0, uint112 reserve1,) = IPonderPair(pair).getReserves();
        uint256 ponderReserve;
        uint256 kubReserve;

        // Determine token ordering
        if (IPonderPair(pair).token0() == IPonderPriceOracle(oracle).baseToken()) {
            kubReserve = reserve0;
            ponderReserve = reserve1;
        } else {
            kubReserve = reserve1;
            ponderReserve = reserve0;
        }

        // Check minimum liquidity
        uint256 totalLiquidity = kubReserve * 2;
        if (totalLiquidity < MIN_LIQUIDITY) revert InsufficientLiquidity();

        // Calculate max PONDER acceptance based on liquidity
        result.maxPonderPercent = _calculatePonderCap(totalLiquidity);

        // Calculate spot price first
        result.kubValue = IPonderPriceOracle(oracle).getCurrentPrice(
            pair,
            IPonderPriceOracle(oracle).baseToken(),
            amount
        );

        if (result.kubValue == 0) revert InvalidPrice();

        // Calculate price impact
        result.priceImpact = _calculatePriceImpact(
            ponderReserve,
            kubReserve,
            amount
        );

        if (result.priceImpact > MAX_PRICE_IMPACT) revert ExcessivePriceImpact();

        return result;
    }

    function validateKubContribution(
        uint256 amount,
        uint256 totalRaised,
        uint256 targetRaise
    ) external pure returns (uint256 acceptedAmount) {
        if (amount == 0) revert ZeroAmount();

        uint256 remaining = targetRaise > totalRaised ?
            targetRaise - totalRaised : 0;

        return amount > remaining ? remaining : amount;
    }

    function _calculatePonderCap(uint256 liquidity) internal pure returns (uint256) {
        if (liquidity >= MAX_LIQUIDITY) {
            return MAX_PONDER_PERCENT;
        }

        if (liquidity <= MIN_LIQUIDITY) {
            return MIN_PONDER_PERCENT;
        }

        uint256 range = MAX_LIQUIDITY - MIN_LIQUIDITY;
        uint256 excess = liquidity - MIN_LIQUIDITY;
        uint256 percentRange = MAX_PONDER_PERCENT - MIN_PONDER_PERCENT;

        return MIN_PONDER_PERCENT + (excess * percentRange) / range;
    }

    function _calculatePriceImpact(
        uint256 ponderReserve,
        uint256 kubReserve,
        uint256 ponderAmount
    ) internal pure returns (uint256) {
        uint256 k = ponderReserve * kubReserve;
        uint256 newPonderReserve = ponderReserve + ponderAmount;
        uint256 newKubReserve = k / newPonderReserve;

        uint256 oldPrice = (kubReserve * BASIS_POINTS) / ponderReserve;
        uint256 newPrice = (newKubReserve * BASIS_POINTS) / newPonderReserve;

        return newPrice > oldPrice ?
            ((newPrice - oldPrice) * BASIS_POINTS) / oldPrice :
            ((oldPrice - newPrice) * BASIS_POINTS) / oldPrice;
    }

    function getAcceptablePonderAmount(
        uint256 totalRaise,
        uint256 currentKub,
        uint256 currentPonderValue,
        uint256 maxPonderPercent
    ) external pure returns (uint256) {
        uint256 maxPonderValue = (totalRaise * maxPonderPercent) / BASIS_POINTS;
        uint256 currentTotal = currentKub + currentPonderValue;

        if (currentTotal >= totalRaise) return 0;
        if (currentPonderValue >= maxPonderValue) return 0;

        uint256 remainingPonderValue = maxPonderValue - currentPonderValue;
        uint256 remainingTotal = totalRaise - currentTotal;

        return remainingPonderValue < remainingTotal ?
            remainingPonderValue : remainingTotal;
    }
}

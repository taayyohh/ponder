// src/interfaces/IPonderSafeguard.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IPonderSafeguard {
    function checkPriceDeviation(
        address pair,
        uint256 amount0Out,
        uint256 amount1Out,
        uint256 amount0In,
        uint256 amount1In
    ) external view returns (bool);

    function checkAndUpdateVolume(
        address pair,
        uint256 amount0In,
        uint256 amount1In
    ) external returns (bool);

    function paused() external view returns (bool);
}

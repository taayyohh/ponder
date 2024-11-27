// src/core/PonderSafeguard.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IPonderPair.sol";
import "../interfaces/IPonderFactory.sol";
import "../interfaces/IPonderSafeguard.sol";

contract PonderSafeguard is IPonderSafeguard {
    // Struct to track volume data
    struct VolumeData {
        uint256 dailyVolume;
        uint256 lastUpdate;
    }

    // Owner/admin role
    address public owner;
    address public pendingOwner;
    bool public paused;

    // Circuit breaker parameters
    uint256 public constant MAX_PRICE_DEVIATION = 20; // 20% maximum price deviation
    uint256 public constant OBSERVATION_PERIOD = 1 hours;

    // Rate limiting parameters
    uint256 public constant DAILY_VOLUME_LIMIT = 1_000_000e18; // Example: 1M tokens daily limit
    mapping(address => VolumeData) public pairVolumes;

    // Emergency contact information
    address public emergencyAdmin;

    // Events
    event PriceDeviationExceeded(address pair, uint256 deviation);
    event VolumeLimitExceeded(address pair, uint256 volume);
    event EmergencyPaused(address caller);
    event EmergencyUnpaused(address caller);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // Errors
    error PriceDeviationTooHigh();
    error DailyVolumeLimitExceeded();
    error Paused();
    error NotOwner();
    error NotEmergencyAdmin();
    error ZeroAddress();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyEmergencyAdmin() {
        if (msg.sender != emergencyAdmin && msg.sender != owner) revert NotEmergencyAdmin();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    constructor() {
        owner = msg.sender;
        emergencyAdmin = msg.sender;
    }

    // Circuit breaker: Check price deviation
    function checkPriceDeviation(
        address pair,
        uint256 amount0Out,
        uint256 amount1Out,
        uint256 amount0In,
        uint256 amount1In
    ) public view override returns (bool) {
        IPonderPair pairContract = IPonderPair(pair);
        (uint112 reserve0, uint112 reserve1,) = pairContract.getReserves();

        // Calculate new reserves after swap
        uint256 newReserve0 = uint256(reserve0) + amount0In - amount0Out;
        uint256 newReserve1 = uint256(reserve1) + amount1In - amount1Out;

        // Calculate price change
        uint256 oldPrice = uint256(reserve0) * 1e18 / reserve1;
        uint256 newPrice = newReserve0 * 1e18 / newReserve1;

        // Calculate price deviation percentage
        uint256 deviation;
        if (newPrice > oldPrice) {
            deviation = ((newPrice - oldPrice) * 100) / oldPrice;
        } else {
            deviation = ((oldPrice - newPrice) * 100) / oldPrice;
        }

        return deviation <= MAX_PRICE_DEVIATION;
    }

    // Rate limiter: Check and update daily volume
    function checkAndUpdateVolume(
        address pair,
        uint256 amount0In,
        uint256 amount1In
    ) public override returns (bool) {
        VolumeData storage volumeData = pairVolumes[pair];

        // Reset daily volume if 24 hours have passed
        if (block.timestamp >= volumeData.lastUpdate + 24 hours) {
            volumeData.dailyVolume = 0;
        }

        // Update volume
        uint256 newVolume = amount0In + amount1In;
        uint256 updatedDailyVolume = volumeData.dailyVolume + newVolume;

        if (updatedDailyVolume > DAILY_VOLUME_LIMIT) {
            return false;
        }

        volumeData.dailyVolume = updatedDailyVolume;
        volumeData.lastUpdate = block.timestamp;
        return true;
    }

    // Emergency stop functionality
    function pause() external onlyEmergencyAdmin {
        paused = true;
        emit EmergencyPaused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit EmergencyUnpaused(msg.sender);
    }

    // Ownership management
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert NotOwner();
        address oldOwner = owner;
        owner = pendingOwner;
        pendingOwner = address(0);
        emit OwnershipTransferred(oldOwner, owner);
    }

    // Emergency admin management
    function setEmergencyAdmin(address newAdmin) external onlyOwner {
        if (newAdmin == address(0)) revert ZeroAddress();
        emergencyAdmin = newAdmin;
    }

    // View functions
    function getDailyVolume(address pair) external view returns (uint256) {
        return pairVolumes[pair].dailyVolume;
    }

    function isPriceDeviationSafe(
        address pair,
        uint256 amount0Out,
        uint256 amount1Out,
        uint256 amount0In,
        uint256 amount1In
    ) external view returns (bool) {
        return checkPriceDeviation(pair, amount0Out, amount1Out, amount0In, amount1In);
    }
}

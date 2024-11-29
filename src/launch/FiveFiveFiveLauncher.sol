// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../core/PonderERC20.sol";
import "../core/PonderFactory.sol";
import "../periphery/PonderRouter.sol";
import "./LaunchToken.sol";
import "../interfaces/IFiveFiveFiveLauncher.sol";

/// @title FiveFiveFiveLauncher
/// @notice A fair launch protocol for token launches with initial liquidity
/// @dev Implements IFiveFiveFiveLauncher interface
contract FiveFiveFiveLauncher is IFiveFiveFiveLauncher {
    /// @notice Struct containing all information about a token launch
    struct LaunchInfo {
        address tokenAddress;
        string name;
        string symbol;
        string imageURI;
        uint256 minToLaunch;
        uint256 creatorFee;
        uint256 protocolFee;
        uint256 totalRaised;
        bool launched;
        address creator;
        uint256 lpUnlockTime;
        mapping(address => uint256) contributions;
    }

    /// @notice Fixed parameters for all launches
    uint256 public constant MIN_TO_LAUNCH = 165 ether;    // 165 KUB (~$500)
    uint256 public constant MIN_CONTRIBUTION = 0.55 ether; // 0.55 KUB
    uint256 public constant TOTAL_SUPPLY = 555_555_555 ether; // 555.5M tokens
    uint256 public constant CREATOR_FEE = 55;   // 0.55%
    uint256 public constant PROTOCOL_FEE = 55;  // 0.55%
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant LP_LOCK_PERIOD = 180 days;

    /// @notice Core protocol addresses and state
    PonderFactory public immutable factory;
    PonderRouter public immutable router;
    address public owner;
    address public feeCollector;

    /// @notice Launch tracking
    mapping(uint256 => LaunchInfo) public launches;
    uint256 public launchCount;

    /// @notice Custom errors
    error LaunchNotFound();
    error AlreadyLaunched();
    error BelowMinContribution();
    error ImageRequired();
    error InvalidTokenParams();
    error Unauthorized();
    error LPStillLocked();

    /// @notice Authorization modifier
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    /// @notice Initializes the launcher with required dependencies
    /// @param _factory The PonderFactory address
    /// @param _router The PonderRouter address
    /// @param _feeCollector The address that will receive protocol fees
    constructor(address _factory, address payable _router, address _feeCollector) {
        factory = PonderFactory(_factory);
        router = PonderRouter(_router);
        feeCollector = _feeCollector;
        owner = msg.sender;
    }

    /// @inheritdoc IFiveFiveFiveLauncher
    function createLaunch(
        string memory name,
        string memory symbol,
        string memory imageURI
    ) external returns (uint256 launchId) {
        if(bytes(imageURI).length == 0) revert ImageRequired();
        _validateTokenParams(name, symbol);

        LaunchToken token = new LaunchToken();
        token.initialize(name, symbol, TOTAL_SUPPLY, address(this));

        launchId = launchCount++;
        LaunchInfo storage launch = launches[launchId];
        launch.tokenAddress = address(token);
        launch.name = name;
        launch.symbol = symbol;
        launch.imageURI = imageURI;
        launch.minToLaunch = MIN_TO_LAUNCH;
        launch.creatorFee = CREATOR_FEE;
        launch.protocolFee = PROTOCOL_FEE;
        launch.creator = msg.sender;

        emit LaunchCreated(launchId, address(token), msg.sender, imageURI);
        emit TokenMinted(launchId, address(token), TOTAL_SUPPLY);
    }

    /// @inheritdoc IFiveFiveFiveLauncher
    function contribute(uint256 launchId) external payable {
        LaunchInfo storage launch = launches[launchId];
        if(launch.tokenAddress == address(0)) revert LaunchNotFound();
        if(launch.launched) revert AlreadyLaunched();
        if(msg.value < MIN_CONTRIBUTION) revert BelowMinContribution();

        launch.contributions[msg.sender] += msg.value;
        launch.totalRaised += msg.value;

        emit Contributed(launchId, msg.sender, msg.value);

        if (launch.totalRaised >= MIN_TO_LAUNCH) {
            _finalizeLaunch(launchId);
        }
    }

    /// @notice Internal function to finalize launch and create LP
    /// @param launchId ID of the launch to finalize
    function _finalizeLaunch(uint256 launchId) internal {
        LaunchInfo storage launch = launches[launchId];
        launch.launched = true;

        uint256 creatorFeeAmount = (launch.totalRaised * launch.creatorFee) / FEE_DENOMINATOR;
        uint256 protocolFeeAmount = (launch.totalRaised * launch.protocolFee) / FEE_DENOMINATOR;
        uint256 liquidityAmount = launch.totalRaised - creatorFeeAmount - protocolFeeAmount;

        // Send fees
        payable(launch.creator).transfer(creatorFeeAmount);
        payable(feeCollector).transfer(protocolFeeAmount);

        // Create LP
        LaunchToken token = LaunchToken(launch.tokenAddress);
        token.enableTransfers();
        token.approve(address(router), TOTAL_SUPPLY);

        router.addLiquidityETH{value: liquidityAmount}(
            launch.tokenAddress,
            TOTAL_SUPPLY,
            0,
            0,
            address(this),
            block.timestamp
        );

        launch.lpUnlockTime = block.timestamp + LP_LOCK_PERIOD;

        emit TransfersEnabled(launchId, launch.tokenAddress);
        emit LaunchFinalized(launchId, liquidityAmount, creatorFeeAmount, protocolFeeAmount);
        emit LiquidityAdded(launchId, liquidityAmount, TOTAL_SUPPLY);
    }

    /// @inheritdoc IFiveFiveFiveLauncher
    function withdrawLP(uint256 launchId) external {
        LaunchInfo storage launch = launches[launchId];
        if(msg.sender != launch.creator) revert Unauthorized();
        if(block.timestamp < launch.lpUnlockTime) revert LPStillLocked();

        address pair = factory.getPair(launch.tokenAddress, router.WETH());
        uint256 lpBalance = PonderERC20(pair).balanceOf(address(this));
        PonderERC20(pair).transfer(launch.creator, lpBalance);

        emit LPTokensWithdrawn(launchId, launch.creator, lpBalance);
    }

    /// @inheritdoc IFiveFiveFiveLauncher
    function getLaunchInfo(uint256 launchId)
    external
    view
    returns (
        address tokenAddress,
        string memory name,
        string memory symbol,
        string memory imageURI,
        uint256 totalRaised,
        bool launched,
        uint256 lpUnlockTime
    )
    {
        LaunchInfo storage launch = launches[launchId];
        return (
            launch.tokenAddress,
            launch.name,
            launch.symbol,
            launch.imageURI,
            launch.totalRaised,
            launch.launched,
            launch.lpUnlockTime
        );
    }

    /// @notice Validates token parameters
    /// @param name Token name to validate
    /// @param symbol Token symbol to validate
    function _validateTokenParams(string memory name, string memory symbol) internal pure {
        bytes memory nameBytes = bytes(name);
        bytes memory symbolBytes = bytes(symbol);
        if(nameBytes.length == 0 || nameBytes.length > 32) revert InvalidTokenParams();
        if(symbolBytes.length == 0 || symbolBytes.length > 8) revert InvalidTokenParams();
    }

    receive() external payable {}
}

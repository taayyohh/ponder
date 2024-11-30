// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../core/PonderFactory.sol";
import "../interfaces/IPonderFactory.sol";
import "../interfaces/IFiveFiveFiveLauncher.sol";
import "../interfaces/ILaunchToken.sol";
import "../periphery/PonderRouter.sol";
import "./LaunchTokenFactory.sol";

/// @title FiveFiveFiveLauncher
/// @notice A token launch protocol optimized for efficient distribution and creator incentives on Bitkub Chain
/// @dev Fair launch mechanism with 5555 KUB target raise
contract FiveFiveFiveLauncher is IFiveFiveFiveLauncher {
    PonderRouter public immutable router;
    IPonderFactory public immutable factory;
    LaunchTokenFactory public immutable tokenFactory;

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
        uint256 tokenPrice;
        uint256 tokensForSale;
        uint256 tokensSold;
    }

    uint256 public constant TARGET_RAISE = 5555 ether;
    uint256 public constant TOTAL_SUPPLY = 555_555_555 ether;
    uint256 public constant CREATOR_FEE = 255;
    uint256 public constant PROTOCOL_FEE = 55;
    uint256 public constant LP_ALLOCATION = 10;
    uint256 public constant CREATOR_ALLOCATION = 10;
    uint256 public constant CONTRIBUTOR_ALLOCATION = 80;
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant LP_LOCK_PERIOD = 180 days;

    address public owner;
    address public feeCollector;

    mapping(uint256 => LaunchInfo) public launches;
    uint256 public launchCount;

    error LaunchNotFound();
    error AlreadyLaunched();
    error InvalidPayment();
    error InvalidAmount();
    error ImageRequired();
    error InvalidTokenParams();
    error Unauthorized();
    error LPStillLocked();
    error SoldOut();

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    constructor(IPonderFactory _factory, address payable _router, address _feeCollector) {
        factory = _factory;
        router = PonderRouter(_router);
        feeCollector = _feeCollector;
        owner = msg.sender;
        tokenFactory = new LaunchTokenFactory();
    }

    function createLaunch(
        string memory name,
        string memory symbol,
        string memory imageURI
    ) external returns (uint256 launchId) {
        if(bytes(imageURI).length == 0) revert ImageRequired();
        _validateTokenParams(name, symbol);

        address tokenAddress = tokenFactory.deployToken();
        ILaunchToken(tokenAddress).initialize(name, symbol, TOTAL_SUPPLY, address(this));

        launchId = launchCount++;
        LaunchInfo storage launch = launches[launchId];
        launch.tokenAddress = tokenAddress;
        launch.name = name;
        launch.symbol = symbol;
        launch.imageURI = imageURI;
        launch.minToLaunch = TARGET_RAISE;
        launch.creatorFee = CREATOR_FEE;
        launch.protocolFee = PROTOCOL_FEE;
        launch.creator = msg.sender;
        launch.tokensForSale = (TOTAL_SUPPLY * CONTRIBUTOR_ALLOCATION) / 100;
        launch.tokenPrice = (TARGET_RAISE * 1e18) / launch.tokensForSale;

        uint256 creatorTokens = (TOTAL_SUPPLY * CREATOR_ALLOCATION) / 100;
        ILaunchToken(tokenAddress).setupVesting(launch.creator, creatorTokens);

        emit LaunchCreated(launchId, tokenAddress, msg.sender, imageURI);
        emit TokenMinted(launchId, tokenAddress, TOTAL_SUPPLY);
    }

    function contribute(uint256 launchId) external payable {
        LaunchInfo storage launch = launches[launchId];
        if(launch.tokenAddress == address(0)) revert LaunchNotFound();
        if(launch.launched) revert AlreadyLaunched();
        if(msg.value == 0) revert InvalidPayment();

        uint256 tokensToReceive = (msg.value * 1e18) / launch.tokenPrice;

        if(launch.tokensSold + tokensToReceive > launch.tokensForSale) revert SoldOut();

        LaunchToken(launch.tokenAddress).transfer(msg.sender, tokensToReceive);
        launch.totalRaised += msg.value;
        launch.tokensSold += tokensToReceive;

        emit Contributed(launchId, msg.sender, msg.value);
        emit TokenPurchased(launchId, msg.sender, msg.value, tokensToReceive);

        if (launch.totalRaised >= TARGET_RAISE) {
            _finalizeLaunch(launchId);
        }
    }

    function _finalizeLaunch(uint256 launchId) internal {
        LaunchInfo storage launch = launches[launchId];
        launch.launched = true;

        uint256 creatorFeeAmount = (launch.totalRaised * launch.creatorFee) / FEE_DENOMINATOR;
        uint256 protocolFeeAmount = (launch.totalRaised * launch.protocolFee) / FEE_DENOMINATOR;
        uint256 liquidityAmount = launch.totalRaised - creatorFeeAmount - protocolFeeAmount;

        payable(launch.creator).transfer(creatorFeeAmount);
        payable(feeCollector).transfer(protocolFeeAmount);

        emit CreatorFeePaid(launchId, launch.creator, creatorFeeAmount);
        emit ProtocolFeePaid(launchId, protocolFeeAmount);

        LaunchToken token = LaunchToken(launch.tokenAddress);
        uint256 lpTokens = (TOTAL_SUPPLY * LP_ALLOCATION) / 100;

        token.approve(address(router), lpTokens);
        token.enableTransfers();

        router.addLiquidityETH{value: liquidityAmount}(
            launch.tokenAddress,
            lpTokens,
            0,
            0,
            address(this),
            block.timestamp
        );

        launch.lpUnlockTime = block.timestamp + LP_LOCK_PERIOD;

        emit TransfersEnabled(launchId, launch.tokenAddress);
        emit LaunchFinalized(launchId, liquidityAmount, creatorFeeAmount, protocolFeeAmount);
        emit LiquidityAdded(launchId, liquidityAmount, lpTokens);
        emit LaunchCompleted(launchId, launch.totalRaised, launch.tokensSold);
    }

    function withdrawLP(uint256 launchId) external {
        LaunchInfo storage launch = launches[launchId];
        if(msg.sender != launch.creator) revert Unauthorized();
        if(block.timestamp < launch.lpUnlockTime) revert LPStillLocked();

        address pair = factory.getPair(launch.tokenAddress, router.WETH());
        uint256 lpBalance = PonderERC20(pair).balanceOf(address(this));
        PonderERC20(pair).transfer(launch.creator, lpBalance);

        emit LPTokensWithdrawn(launchId, launch.creator, lpBalance);
    }

    function getLaunchInfo(uint256 launchId) external view returns (
        address tokenAddress,
        string memory name,
        string memory symbol,
        string memory imageURI,
        uint256 totalRaised,
        bool launched,
        uint256 lpUnlockTime
    ) {
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

    function getSaleInfo(uint256 launchId) external view returns (
        uint256 tokenPrice,
        uint256 tokensForSale,
        uint256 tokensSold,
        uint256 totalRaised,
        bool launched,
        uint256 remainingTokens
    ) {
        LaunchInfo storage launch = launches[launchId];
        return (
            launch.tokenPrice,
            launch.tokensForSale,
            launch.tokensSold,
            launch.totalRaised,
            launch.launched,
            launch.tokensForSale - launch.tokensSold
        );
    }

    function _validateTokenParams(string memory name, string memory symbol) internal pure {
        bytes memory nameBytes = bytes(name);
        bytes memory symbolBytes = bytes(symbol);
        if(nameBytes.length == 0 || nameBytes.length > 32) revert InvalidTokenParams();
        if(symbolBytes.length == 0 || symbolBytes.length > 8) revert InvalidTokenParams();
    }

    receive() external payable {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../core/PonderFactory.sol";
import "../interfaces/IPonderFactory.sol";
import "../interfaces/IFiveFiveFiveLauncher.sol";
import "../periphery/PonderRouter.sol";
import "./LaunchToken.sol";

/**
 * @title FiveFiveFiveLauncher
 * @notice A fair launch protocol targeting 5555 KUB raises with creator incentives
 * @dev Manages token launches with automated liquidity provision and vesting
 * @custom:security-contact security@ponder.exchange
 */
contract FiveFiveFiveLauncher is IFiveFiveFiveLauncher {
    /// @notice Core protocol references
    IPonderFactory public immutable factory;
    IPonderRouter public immutable router;

    /**
     * @notice Launch information structure
     * @param tokenAddress Address of the launched token
     * @param name Token name
     * @param symbol Token symbol
     * @param imageURI Token image URI
     * @param totalRaised Total KUB collected
     * @param launched Whether launch is completed
     * @param creator Launch creator address
     * @param lpUnlockTime When LP tokens can be withdrawn
     * @param tokenPrice Fixed price per token
     * @param tokensForSale Total tokens in sale
     * @param tokensSold Tokens sold so far
     */
    struct LaunchInfo {
        address tokenAddress;
        string name;
        string symbol;
        string imageURI;
        uint256 totalRaised;
        bool launched;
        address creator;
        uint256 lpUnlockTime;
        uint256 tokenPrice;
        uint256 tokensForSale;
        uint256 tokensSold;
    }

    /// @notice Protocol constants
    uint256 public constant TARGET_RAISE = 5555 ether;
    uint256 public constant TOTAL_SUPPLY = 555_555_555 ether;
    uint256 public constant CREATOR_FEE = 255; // 2.55%
    uint256 public constant PROTOCOL_FEE = 55; // 0.55%
    uint256 public constant LP_ALLOCATION = 10; // 10%
    uint256 public constant CREATOR_ALLOCATION = 10; // 10%
    uint256 public constant CONTRIBUTOR_ALLOCATION = 80; // 80%
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant LP_LOCK_PERIOD = 180 days;

    /// @notice Protocol state
    address public owner;
    address public feeCollector;
    uint256 public launchCount;
    mapping(uint256 => LaunchInfo) public launches;

    /// @notice Custom errors
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

    /**
     * @notice Initializes the launcher contract
     * @param _factory Factory contract address
     * @param _router Router contract address
     * @param _feeCollector Protocol fee collector address
     */
    constructor(
        address _factory,
        address payable _router,
        address _feeCollector
    ) {
        factory = IPonderFactory(_factory);
        router = IPonderRouter(_router);
        feeCollector = _feeCollector;
        owner = msg.sender;
    }
    /**
     * @notice Creates a new token launch
     * @param name Token name
     * @param symbol Token symbol
     * @param imageURI Token image URI
     * @return launchId Unique identifier for the launch
     */
    function createLaunch(
        string memory name,
        string memory symbol,
        string memory imageURI
    ) external returns (uint256 launchId) {
        if(bytes(imageURI).length == 0) revert ImageRequired();
        _validateTokenParams(name, symbol);

        launchId = launchCount++;
        LaunchInfo storage launch = launches[launchId];

        // Deploy token
        LaunchToken token = new LaunchToken(
            name,
            symbol,
            address(this),
            address(factory),
            payable(address(router))
        );

        launch.tokenAddress = address(token);
        launch.name = name;
        launch.symbol = symbol;
        launch.imageURI = imageURI;
        launch.creator = msg.sender;

        // Calculate allocations
        uint256 tokensForSale = (token.TOTAL_SUPPLY() * CONTRIBUTOR_ALLOCATION) / 100;
        launch.tokensForSale = tokensForSale;

        // Initialize token price (5555 KUB for 80% of supply)
        launch.tokenPrice = (TARGET_RAISE * 1e18) / tokensForSale;

        // Setup creator vesting
        uint256 creatorTokens = (token.TOTAL_SUPPLY() * CREATOR_ALLOCATION) / 100;
        token.setupVesting(msg.sender, creatorTokens);

        emit LaunchCreated(launchId, address(token), msg.sender, imageURI);
        emit TokenMinted(launchId, address(token), token.TOTAL_SUPPLY());
    }


    /**
     * @notice Allows users to contribute KUB to a launch
     * @param launchId ID of the launch
     */
    function contribute(uint256 launchId) external payable {
        LaunchInfo storage launch = launches[launchId];
        if(launch.tokenAddress == address(0)) revert LaunchNotFound();
        if(launch.launched) revert AlreadyLaunched();
        if(msg.value == 0) revert InvalidPayment();

        // Check we haven't exceeded target raise
        if(launch.totalRaised + msg.value > TARGET_RAISE) revert InvalidAmount();

        // Calculate tokens using fixed price per token
        uint256 tokensToReceive = (msg.value * launch.tokensForSale) / TARGET_RAISE;

        // Verify no overflow of total allocation
        if(launch.tokensSold + tokensToReceive > launch.tokensForSale) revert SoldOut();

        // Update state
        launch.tokensSold += tokensToReceive;
        launch.totalRaised += msg.value;

        // Transfer tokens
        LaunchToken(launch.tokenAddress).transfer(msg.sender, tokensToReceive);

        emit Contributed(launchId, msg.sender, msg.value);
        emit TokenPurchased(launchId, msg.sender, msg.value, tokensToReceive);

        if (launch.totalRaised >= TARGET_RAISE) {
            _finalizeLaunch(launchId);
        }
    }

    /**
     * @notice Finalizes a launch after reaching target
     * @param launchId Launch ID to finalize
     */
    function _finalizeLaunch(uint256 launchId) internal {
        LaunchInfo storage launch = launches[launchId];
        launch.launched = true;

        // Calculate and distribute fees
        uint256 creatorFeeAmount = (launch.totalRaised * CREATOR_FEE) / FEE_DENOMINATOR;
        uint256 protocolFeeAmount = (launch.totalRaised * PROTOCOL_FEE) / FEE_DENOMINATOR;
        uint256 liquidityAmount = launch.totalRaised - creatorFeeAmount - protocolFeeAmount;

        payable(launch.creator).transfer(creatorFeeAmount);
        payable(feeCollector).transfer(protocolFeeAmount);

        // Setup liquidity
        LaunchToken token = LaunchToken(launch.tokenAddress);
        uint256 lpTokens = (TOTAL_SUPPLY * LP_ALLOCATION) / 100;

        token.approve(address(router), lpTokens);

        router.addLiquidityETH{value: liquidityAmount}(
            launch.tokenAddress,
            lpTokens,
            0,
            0,
            address(this),
            block.timestamp
        );

        launch.lpUnlockTime = block.timestamp + LP_LOCK_PERIOD;

        // Emit events
        emit CreatorFeePaid(launchId, launch.creator, creatorFeeAmount);
        emit ProtocolFeePaid(launchId, protocolFeeAmount);
        emit LaunchFinalized(launchId, liquidityAmount, creatorFeeAmount, protocolFeeAmount);
        emit LiquidityAdded(launchId, liquidityAmount, lpTokens);
        emit LaunchCompleted(launchId, launch.totalRaised, launch.tokensSold);
    }

    /**
     * @notice Withdraws LP tokens after lock period
     * @param launchId Launch ID to withdraw from
     */
    function withdrawLP(uint256 launchId) external {
        LaunchInfo storage launch = launches[launchId];
        if(msg.sender != launch.creator) revert Unauthorized();
        if(block.timestamp < launch.lpUnlockTime) revert LPStillLocked();

        address pair = factory.getPair(launch.tokenAddress, router.WETH());
        uint256 lpBalance = PonderERC20(pair).balanceOf(address(this));
        PonderERC20(pair).transfer(launch.creator, lpBalance);

        emit LPTokensWithdrawn(launchId, launch.creator, lpBalance);
    }

    /**
     * @notice Gets launch information
     * @param launchId Launch ID to query
     */
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

    /**
     * @notice Gets sale information
     * @param launchId Launch ID to query
     */
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

    /**
     * @notice Validates token parameters
     * @param name Token name to validate
     * @param symbol Token symbol to validate
     */
    function _validateTokenParams(string memory name, string memory symbol) internal pure {
        bytes memory nameBytes = bytes(name);
        bytes memory symbolBytes = bytes(symbol);
        if(nameBytes.length == 0 || nameBytes.length > 32) revert InvalidTokenParams();
        if(symbolBytes.length == 0 || symbolBytes.length > 8) revert InvalidTokenParams();
    }

    /// @notice Allows contract to receive ETH
    receive() external payable {}
}

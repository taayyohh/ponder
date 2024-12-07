// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../core/PonderFactory.sol";
import "../interfaces/IPonderFactory.sol";
import "../interfaces/IFiveFiveFiveLauncher.sol";
import "../periphery/PonderRouter.sol";
import "./LaunchToken.sol";
import "../core/PonderToken.sol";
import "../core/PonderPriceOracle.sol";

/**
 * @title FiveFiveFiveLauncher
 * @notice A fair launch protocol targeting 5555 KUB value with creator incentives
 * @dev Manages token launches with automated liquidity provision and vesting
 * @custom:security-contact security@ponder.exchange
 */
contract FiveFiveFiveLauncher is IFiveFiveFiveLauncher {
    /// @notice Core protocol references
    IPonderFactory public immutable factory;
    IPonderRouter public immutable router;
    PonderToken public immutable ponder;
    PonderPriceOracle public immutable priceOracle;

    /**
     * @notice Launch information structure
     * @param tokenAddress Address of the launched token
     * @param name Token name
     * @param symbol Token symbol
     * @param imageURI URI for token image
     * @param totalRaised Total amount raised in KUB value
     * @param launched Whether the launch has been completed
     * @param creator Address of launch creator
     * @param lpUnlockTime Timestamp when LP tokens can be withdrawn
     * @param tokenPrice Price per token in PONDER
     * @param tokensForSale Total tokens available for sale
     * @param tokensSold Number of tokens sold
     * @param ponderRequired Total PONDER needed for launch
     * @param ponderCollected Total PONDER collected so far
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
        uint256 ponderRequired;
        uint256 ponderCollected;
    }

    /// @notice Protocol constants
    uint256 public constant TARGET_RAISE = 5555 ether;      // Target value in KUB
    uint256 public constant TOTAL_SUPPLY = 555_555_555 ether;
    uint256 public constant LP_ALLOCATION = 10;             // 10% of launch tokens for LP
    uint256 public constant CREATOR_ALLOCATION = 10;        // 10% to creator
    uint256 public constant CONTRIBUTOR_ALLOCATION = 80;    // 80% for sale
    uint256 public constant LP_LOCK_PERIOD = 180 days;

    // PONDER distribution ratios
    uint256 public constant PONDER_LP_ALLOCATION = 50;      // 50% to launch token/PONDER LP
    uint256 public constant PONDER_PROTOCOL_LP = 30;        // 30% to PONDER/KUB LP
    uint256 public constant PONDER_BURN = 20;              // 20% burned

    /// @notice Fee denominator for percentage calculations
    uint256 public constant FEE_DENOMINATOR = 10000;

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
    error InsufficientPonder();
    error PriceOracleError();

    /// @notice Events are defined in IFiveFiveFiveLauncher interface

    /**
     * @notice Ensures caller is contract owner
     */
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    /**
     * @notice Initializes the launch platform
     * @param _factory Address of PonderFactory
     * @param _router Address of PonderRouter
     * @param _feeCollector Address to collect protocol fees
     * @param _ponder Address of PONDER token
     * @param _priceOracle Address of price oracle
     */
    constructor(
        address _factory,
        address payable _router,
        address _feeCollector,
        address _ponder,
        address _priceOracle
    ) {
        factory = IPonderFactory(_factory);
        router = IPonderRouter(_router);
        ponder = PonderToken(_ponder);
        priceOracle = PonderPriceOracle(_priceOracle);
        feeCollector = _feeCollector;
        owner = msg.sender;
    }

    /**
     * @notice Creates a new token launch
     * @param name Token name
     * @param symbol Token symbol
     * @param imageURI URI for token image
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
            payable(address(router)),
            address(ponder)
        );

        launch.tokenAddress = address(token);
        launch.name = name;
        launch.symbol = symbol;
        launch.imageURI = imageURI;
        launch.creator = msg.sender;

        // Calculate allocations
        uint256 tokensForSale = (token.TOTAL_SUPPLY() * CONTRIBUTOR_ALLOCATION) / 100;
        launch.tokensForSale = tokensForSale;

        // Calculate required PONDER based on TWAP
        try priceOracle.consult(
            factory.getPair(address(ponder), router.WETH()),
            router.WETH(),
            TARGET_RAISE,
            24 hours
        ) returns (uint256 ponderRequired) {
            launch.ponderRequired = ponderRequired;
        } catch {
            revert PriceOracleError();
        }

        // Setup creator vesting
        uint256 creatorTokens = (token.TOTAL_SUPPLY() * CREATOR_ALLOCATION) / 100;
        token.setupVesting(msg.sender, creatorTokens);

        emit LaunchCreated(launchId, address(token), msg.sender, imageURI);
        emit TokenMinted(launchId, address(token), token.TOTAL_SUPPLY());
    }

    /**
     * @notice Allows users to contribute PONDER to a launch
     * @param launchId The ID of the launch to contribute to
     */
    function contribute(uint256 launchId) external {
        LaunchInfo storage launch = launches[launchId];
        if(launch.tokenAddress == address(0)) revert LaunchNotFound();
        if(launch.launched) revert AlreadyLaunched();

        // Calculate exact PONDER required based on current price
        uint256 ponderRequired;
        try priceOracle.consult(
            factory.getPair(address(ponder), router.WETH()),
            router.WETH(),
            TARGET_RAISE,
            24 hours
        ) returns (uint256 amount) {
            ponderRequired = amount;
        } catch {
            revert PriceOracleError();
        }

        // Ensure user has enough PONDER including potential slippage
        uint256 requiredWithBuffer = ponderRequired * 120 / 100; // Add 20% buffer
        if (ponder.balanceOf(msg.sender) < requiredWithBuffer) revert InsufficientPonder();

        // Transfer PONDER from contributor
        ponder.transferFrom(msg.sender, address(this), ponderRequired);

        // Calculate tokens to receive (80% of total supply)
        uint256 tokensToReceive = (LaunchToken(launch.tokenAddress).TOTAL_SUPPLY() * CONTRIBUTOR_ALLOCATION) / 100;

        // Update state
        launch.tokensSold = tokensToReceive;
        launch.ponderCollected = ponderRequired;

        // Transfer launch tokens
        LaunchToken(launch.tokenAddress).transfer(msg.sender, tokensToReceive);

        emit PonderContributed(launchId, msg.sender, ponderRequired);
        emit TokenPurchased(launchId, msg.sender, ponderRequired, tokensToReceive);

        // Always finalize after successful contribution
        _finalizeLaunch(launchId);
    }

    /**
     * @notice Finalizes a launch by setting up liquidity and burning tokens
     * @param launchId The ID of the launch to finalize
     */
    function _finalizeLaunch(uint256 launchId) internal {
        LaunchInfo storage launch = launches[launchId];
        launch.launched = true;

        uint256 totalPonder = launch.ponderCollected;

        // 1. Create launch token/PONDER LP
        uint256 lpPonderAmount = (totalPonder * PONDER_LP_ALLOCATION) / 100;
        _addLaunchTokenPonderLP(launch.tokenAddress, lpPonderAmount);

        // 2. Add to PONDER/KUB LP
        uint256 protocolLPAmount = (totalPonder * PONDER_PROTOCOL_LP) / 100;
        _addPonderKubLP(protocolLPAmount, launch.ponderRequired);

        // 3. First approve burn amount
        uint256 burnAmount = (totalPonder * PONDER_BURN) / 100;
        ponder.approve(address(ponder), burnAmount);

        // 4. Then burn - using this contract's address
        try ponder.burn(burnAmount) {
            emit PonderBurned(launchId, burnAmount);
        } catch {
            // If direct burn fails, transfer to this contract first
            ponder.transfer(address(this), burnAmount);
            try ponder.burn(burnAmount) {
                emit PonderBurned(launchId, burnAmount);
            } catch Error(string memory reason) {
                revert(string(abi.encodePacked("Burn failed: ", reason)));
            }
        }

        launch.lpUnlockTime = block.timestamp + LP_LOCK_PERIOD;

        emit LaunchFinalized(launchId, lpPonderAmount, protocolLPAmount, burnAmount);
        emit LaunchCompleted(launchId, launch.ponderCollected, launch.tokensSold);
    }

    /**
     * @notice Adds liquidity to launch token/PONDER pair
     * @param launchToken Address of launch token
     * @param ponderAmount Amount of PONDER to add as liquidity
     */
    function _addLaunchTokenPonderLP(address launchToken, uint256 ponderAmount) internal {
        LaunchToken token = LaunchToken(launchToken);
        uint256 launchTokenAmount = (token.TOTAL_SUPPLY() * LP_ALLOCATION) / 100;

        // Ensure sufficient approvals
        token.approve(address(router), launchTokenAmount);
        ponder.approve(address(router), ponderAmount);

        // Add liquidity with minimum amounts set to 98% to allow for small price movements
        uint256 minPonder = ponderAmount * 98 / 100;
        uint256 minLaunchToken = launchTokenAmount * 98 / 100;

        router.addLiquidity(
            launchToken,
            address(ponder),
            launchTokenAmount,
            ponderAmount,
            minLaunchToken,
            minPonder,
            address(this),
            block.timestamp
        );
    }

    /**
     * @notice Adds liquidity to PONDER/KUB pair
     * @param ponderAmount Amount of PONDER to add as liquidity
     * @param launchPonderRequired Total PONDER required for the launch
     */
    function _addPonderKubLP(uint256 ponderAmount, uint256 launchPonderRequired) internal {
        // Add liquidity with minimum amounts set to 98% to allow for small price movements
        ponder.approve(address(router), ponderAmount);
        uint256 minPonder = ponderAmount * 98 / 100;

        // Calculate ETH value based on the launch's PONDER requirement
        uint256 ethValue = TARGET_RAISE * ponderAmount / launchPonderRequired;

        router.addLiquidityETH{value: ethValue}(
            address(ponder),
            ponderAmount,
            minPonder,
            ethValue * 98 / 100,
            address(this),
            block.timestamp
        );
    }

    /**
     * @notice Allows creator to withdraw LP tokens after lock period
     * @param launchId The ID of the launch to withdraw from
     */
    function withdrawLP(uint256 launchId) external {
        LaunchInfo storage launch = launches[launchId];
        if(msg.sender != launch.creator) revert Unauthorized();
        if(block.timestamp < launch.lpUnlockTime) revert LPStillLocked();

        address pairPonder = factory.getPair(launch.tokenAddress, address(ponder));
        uint256 lpBalancePonder = PonderERC20(pairPonder).balanceOf(address(this));
        PonderERC20(pairPonder).transfer(launch.creator, lpBalancePonder);

        emit LPTokensWithdrawn(launchId, launch.creator, lpBalancePonder);
    }

    /**
     * @notice Gets all information about a specific launch
     * @param launchId The ID of the launch to query
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
     * @notice Gets sale-specific information about a launch
     * @param launchId The ID of the launch to query
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
     * @notice Validates token name and symbol parameters
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

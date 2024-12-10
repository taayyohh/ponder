// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../core/PonderFactory.sol";
import "../interfaces/IPonderFactory.sol";
import "./LaunchToken.sol";
import "../core/PonderToken.sol";
import "../core/PonderPriceOracle.sol";
import "../libraries/PonderLaunchGuard.sol";

contract FiveFiveFiveLauncher {
    struct LaunchInfo {
        address tokenAddress;
        string name;
        string symbol;
        string imageURI;
        bool launched;
        address creator;
        uint256 lpUnlockTime;

        // Contribution tracking
        uint256 kubCollected;            // Total KUB collected
        uint256 ponderCollected;         // Total PONDER collected
        uint256 ponderValueCollected;    // KUB value of PONDER collected

        // Pool info
        address memeKubPair;             // Primary trading pair
        address memePonderPair;          // Secondary trading pair

        // Contribution limits
        uint256 remainingPonderCap;      // Remaining PONDER acceptance (in KUB value)
    }

    /// @notice Protocol constants
    uint256 public constant TARGET_RAISE = 5555 ether;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_PONDER_PERCENT = 2000;  // 20% max PONDER
    uint256 public constant LP_LOCK_PERIOD = 180 days;

    // KUB distribution
    uint256 public constant KUB_TO_MEME_KUB_LP = 6000;     // 60% to Meme/KUB LP
    uint256 public constant KUB_TO_PONDER_KUB_LP = 2000;   // 20% to PONDER/KUB LP
    uint256 public constant KUB_TO_MEME_PONDER_LP = 2000;  // 20% to Meme/PONDER LP

    // PONDER distribution
    uint256 public constant PONDER_TO_MEME_PONDER = 8000;  // 80% to Meme/PONDER LP
    uint256 public constant PONDER_TO_BURN = 2000;         // 20% to burn

    /// @notice Core protocol references
    IPonderFactory public immutable factory;
    IPonderRouter public immutable router;
    PonderToken public immutable ponder;
    PonderPriceOracle public immutable priceOracle;

    /// @notice Protocol state
    address public owner;
    address public feeCollector;
    uint256 public launchCount;
    mapping(uint256 => LaunchInfo) public launches;

    /// @notice Events
    event LaunchCreated(uint256 indexed launchId, address indexed token, address creator, string imageURI);
    event KUBContributed(uint256 indexed launchId, address contributor, uint256 amount);
    event PonderContributed(uint256 indexed launchId, address contributor, uint256 amount, uint256 kubValue);
    event DualPoolsCreated(
        uint256 indexed launchId,
        address memeKubPair,
        address memePonderPair,
        uint256 kubLiquidity,
        uint256 ponderLiquidity
    );
    event LaunchCompleted(uint256 indexed launchId, uint256 kubRaised, uint256 ponderRaised);
    event LPTokensWithdrawn(uint256 indexed launchId, address indexed creator, uint256 amount);

    /// @notice Custom errors
    error LaunchNotFound();
    error AlreadyLaunched();
    error InvalidPayment();
    error InvalidAmount();
    error ImageRequired();
    error InvalidTokenParams();
    error Unauthorized();
    error LPStillLocked();
    error PonderCapExceeded();
    error InsufficientPonder();

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

        // Set initial PONDER acceptance cap
        launch.remainingPonderCap = (TARGET_RAISE * MAX_PONDER_PERCENT) / BASIS_POINTS;

        // Setup creator vesting
        uint256 creatorTokens = (token.TOTAL_SUPPLY() * 10) / 100; // 10% to creator
        token.setupVesting(msg.sender, creatorTokens);

        emit LaunchCreated(launchId, address(token), msg.sender, imageURI);
    }

    function contributeKUB(uint256 launchId) external payable {
        LaunchInfo storage launch = launches[launchId];

        if(launch.tokenAddress == address(0)) revert LaunchNotFound();
        if(launch.launched) revert AlreadyLaunched();
        if(msg.value == 0) revert InvalidAmount();

        launch.kubCollected += msg.value;

        emit KUBContributed(launchId, msg.sender, msg.value);

        if (launch.kubCollected + launch.ponderValueCollected >= TARGET_RAISE) {
            _finalizeLaunch(launchId);
        }
    }

    function contributePonder(uint256 launchId, uint256 amount) external {
        LaunchInfo storage launch = launches[launchId];

        if(launch.tokenAddress == address(0)) revert LaunchNotFound();
        if(launch.launched) revert AlreadyLaunched();
        if(amount == 0) revert InvalidAmount();

        // Get PONDER contribution value in KUB
        uint256 ponderValue = priceOracle.consult(
            factory.getPair(address(ponder), router.WETH()),
            router.WETH(),
            amount,
            24 hours
        );

        // Verify within remaining cap
        if (ponderValue > launch.remainingPonderCap) {
            revert PonderCapExceeded();
        }

        // Update state
        launch.ponderCollected += amount;
        launch.ponderValueCollected += ponderValue;
        launch.remainingPonderCap -= ponderValue;

        // Transfer PONDER
        ponder.transferFrom(msg.sender, address(this), amount);

        emit PonderContributed(launchId, msg.sender, amount, ponderValue);

        if (launch.kubCollected + launch.ponderValueCollected >= TARGET_RAISE) {
            _finalizeLaunch(launchId);
        }
    }

    function _finalizeLaunch(uint256 launchId) internal {
        LaunchInfo storage launch = launches[launchId];
        launch.launched = true;

        LaunchToken token = LaunchToken(launch.tokenAddress);

        // 1. Create and fund KUB pool
        uint256 kubToMainPool = (launch.kubCollected * KUB_TO_MEME_KUB_LP) / BASIS_POINTS;
        launch.memeKubPair = _createKubPool(launch.tokenAddress, kubToMainPool);

        // 2. Create and fund PONDER pool
        if (launch.ponderCollected > 0) {
            launch.memePonderPair = _createPonderPool(
                launch.tokenAddress,
                launch.ponderCollected,
                (launch.kubCollected * KUB_TO_MEME_PONDER_LP) / BASIS_POINTS
            );
        }

        // 3. Boost PONDER/KUB liquidity
        uint256 kubToPonderLiquidity = (launch.kubCollected * KUB_TO_PONDER_KUB_LP) / BASIS_POINTS;
        _boostPonderLiquidity(kubToPonderLiquidity);

        // 4. Burn PONDER portion
        uint256 ponderToBurn = (launch.ponderCollected * PONDER_TO_BURN) / BASIS_POINTS;
        ponder.burn(ponderToBurn);

        // 5. Enable trading and set pools
        token.setPairs(launch.memeKubPair, launch.memePonderPair);
        token.enableTransfers();

        // 6. Set LP unlock time
        launch.lpUnlockTime = block.timestamp + LP_LOCK_PERIOD;

        emit LaunchCompleted(launchId, launch.kubCollected, launch.ponderCollected);
    }

    // Previous code remains the same until _createKubPool...

    function _createKubPool(address tokenAddress, uint256 kubAmount) internal returns (address) {
        // Calculate token amount for liquidity
        uint256 tokenAmount = _calculateTokenAmount(kubAmount);

        // Create pair through factory
        address pair = factory.createPair(tokenAddress, router.WETH());

        // Approve token transfer
        LaunchToken(tokenAddress).approve(address(router), tokenAmount);

        // Add liquidity with ETH
        router.addLiquidityETH{value: kubAmount}(
            tokenAddress,
            tokenAmount,
            tokenAmount * 99 / 100,  // 1% slippage tolerance
            kubAmount * 99 / 100,    // 1% slippage tolerance
            address(this),
            block.timestamp + 1 hours
        );

        return pair;
    }

    function _createPonderPool(
        address tokenAddress,
        uint256 ponderAmount,
        uint256 kubAmount
    ) internal returns (address) {
        // Calculate token amount based on ponder value
        uint256 tokenAmount = _calculateTokenAmount(kubAmount);

        // Create pair through factory
        address pair = factory.createPair(tokenAddress, address(ponder));

        // Approve transfers
        LaunchToken(tokenAddress).approve(address(router), tokenAmount);
        ponder.approve(address(router), ponderAmount);

        // Add liquidity
        router.addLiquidity(
            tokenAddress,
            address(ponder),
            tokenAmount,
            ponderAmount,
            tokenAmount * 99 / 100,  // 1% slippage tolerance
            ponderAmount * 99 / 100, // 1% slippage tolerance
            address(this),
            block.timestamp + 1 hours
        );

        return pair;
    }

    function _boostPonderLiquidity(uint256 kubAmount) internal {
        address ponderKubPair = factory.getPair(address(ponder), router.WETH());
        require(ponderKubPair != address(0), "PONDER-KUB pair not found");

        // Get current price from oracle
        (uint256 ponderPrice,,) = priceOracle.getLatestPrice(ponderKubPair);

        // Calculate PONDER amount for liquidity
        uint256 ponderAmount = (kubAmount * 1e18) / ponderPrice;

        // Transfer PONDER from existing supply
        ponder.approve(address(router), ponderAmount);

        // Add liquidity with ETH
        router.addLiquidityETH{value: kubAmount}(
            address(ponder),
            ponderAmount,
            ponderAmount * 99 / 100,  // 1% slippage tolerance
            kubAmount * 99 / 100,     // 1% slippage tolerance
            address(this),
            block.timestamp + 1 hours
        );
    }

    function _calculateTokenAmount(uint256 kubAmount) internal pure returns (uint256) {
        // Price calculation: 5555 KUB = 555,555,555 tokens (launch token)
        return (kubAmount * 555_555_555e18) / 5555 ether;
    }

    function withdrawLP(uint256 launchId) external {
        LaunchInfo storage launch = launches[launchId];
        if(msg.sender != launch.creator) revert Unauthorized();
        if(block.timestamp < launch.lpUnlockTime) revert LPStillLocked();

        // Withdraw from KUB pair
        if (launch.memeKubPair != address(0)) {
            uint256 kubLpBalance = PonderERC20(launch.memeKubPair).balanceOf(address(this));
            PonderERC20(launch.memeKubPair).transfer(launch.creator, kubLpBalance);
        }

        // Withdraw from PONDER pair if it exists
        if (launch.memePonderPair != address(0)) {
            uint256 ponderLpBalance = PonderERC20(launch.memePonderPair).balanceOf(address(this));
            PonderERC20(launch.memePonderPair).transfer(launch.creator, ponderLpBalance);
        }

        emit LPTokensWithdrawn(launchId, launch.creator, block.timestamp);
    }

    /// @notice Gets all information about a specific launch
    function getLaunchInfo(uint256 launchId) external view returns (
        address tokenAddress,
        string memory name,
        string memory symbol,
        string memory imageURI,
        uint256 kubRaised,
        bool launched,
        uint256 lpUnlockTime
    ) {
        LaunchInfo storage launch = launches[launchId];
        return (
            launch.tokenAddress,
            launch.name,
            launch.symbol,
            launch.imageURI,
            launch.kubCollected,
            launch.launched,
            launch.lpUnlockTime
        );
    }

    /// @notice Gets contribution info for a launch
    function getContributionInfo(uint256 launchId) external view returns (
        uint256 kubCollected,
        uint256 ponderCollected,
        uint256 ponderValueCollected,
        uint256 remainingPonderCap,
        uint256 totalValueCollected
    ) {
        LaunchInfo storage launch = launches[launchId];
        return (
            launch.kubCollected,
            launch.ponderCollected,
            launch.ponderValueCollected,
            launch.remainingPonderCap,
            launch.kubCollected + launch.ponderValueCollected
        );
    }

    /// @notice Gets pool information for a launch
    function getPoolInfo(uint256 launchId) external view returns (
        address memeKubPair,
        address memePonderPair,
        bool hasSecondaryPool
    ) {
        LaunchInfo storage launch = launches[launchId];
        return (
            launch.memeKubPair,
            launch.memePonderPair,
            launch.memePonderPair != address(0)
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

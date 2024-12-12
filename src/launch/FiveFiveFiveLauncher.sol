// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../core/PonderFactory.sol";
import "../interfaces/IPonderFactory.sol";
import "../libraries/PonderLaunchGuard.sol";
import "./LaunchToken.sol";
import "../core/PonderToken.sol";
import "../core/PonderPriceOracle.sol";

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
        uint256 kubCollected;
        uint256 ponderCollected;
        uint256 ponderValueCollected;

        // Pool info
        address memeKubPair;
        address memePonderPair;
    }

    struct PoolConfig {
        uint256 kubAmount;
        uint256 tokenAmount;
        uint256 ponderAmount;
    }

    /// @notice Protocol constants
    uint256 public constant TARGET_RAISE = 5555 ether;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant LP_LOCK_PERIOD = 180 days;

    // Distribution constants
    uint256 public constant KUB_TO_MEME_KUB_LP = 6000;
    uint256 public constant KUB_TO_PONDER_KUB_LP = 2000;
    uint256 public constant KUB_TO_MEME_PONDER_LP = 2000;
    uint256 public constant PONDER_TO_MEME_PONDER = 8000;
    uint256 public constant PONDER_TO_BURN = 2000;
    uint256 public constant PRICE_STALENESS_THRESHOLD = 2 hours;


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
    event LaunchCompleted(uint256 indexed launchId, uint256 kubRaised, uint256 ponderRaised);
    event LPTokensWithdrawn(uint256 indexed launchId, address indexed creator, uint256 amount);
    event PonderBurned(uint256 indexed launchId, uint256 amount);
    event DualPoolsCreated(uint256 indexed launchId, address memeKubPair, address memePonderPair, uint256 kubLiquidity, uint256 ponderLiquidity);

    /// @notice Custom errors
    error LaunchNotFound();
    error AlreadyLaunched();
    error InvalidPayment();
    error InvalidAmount();
    error ImageRequired();
    error InvalidTokenParams();
    error Unauthorized();
    error LPStillLocked();
    error StalePrice();
    error ExcessiveContribution();

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
        string calldata name,
        string calldata symbol,
        string calldata imageURI
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

        // Setup creator vesting
        uint256 creatorTokens = (token.TOTAL_SUPPLY() * 10) / 100;
        token.setupVesting(msg.sender, creatorTokens);

        emit LaunchCreated(launchId, address(token), msg.sender, imageURI);
    }

    function contributeKUB(uint256 launchId) external payable {
        LaunchInfo storage launch = launches[launchId];
        if(launch.tokenAddress == address(0)) revert LaunchNotFound();
        if(launch.launched) revert AlreadyLaunched();
        if(msg.value == 0) revert InvalidAmount();

        uint256 remaining = TARGET_RAISE - (launch.kubCollected + launch.ponderValueCollected);
        uint256 contribution = msg.value > remaining ? remaining : msg.value;

        launch.kubCollected += contribution;

        if (msg.value > contribution) {
            payable(msg.sender).transfer(msg.value - contribution);
        }

        emit KUBContributed(launchId, msg.sender, contribution);

        if (launch.kubCollected + launch.ponderValueCollected >= TARGET_RAISE) {
            _finalizeLaunch(launchId);
        }
    }

    function contributePONDER(uint256 launchId, uint256 amount) external {
        if(amount == 0) revert InvalidAmount();
        LaunchInfo storage launch = launches[launchId];

        if(launch.tokenAddress == address(0)) revert LaunchNotFound();
        if(launch.launched) revert AlreadyLaunched();

        // Get PONDER value
        uint256 kubValue = _getPonderValue(amount);
        uint256 remaining = TARGET_RAISE - (launch.kubCollected + launch.ponderValueCollected);
        if (kubValue > remaining) revert ExcessiveContribution();

        // Update state
        launch.ponderCollected += amount;
        launch.ponderValueCollected += kubValue;

        // Transfer PONDER
        ponder.transferFrom(msg.sender, address(this), amount);

        emit PonderContributed(launchId, msg.sender, amount, kubValue);

        if (launch.kubCollected + launch.ponderValueCollected >= TARGET_RAISE) {
            _finalizeLaunch(launchId);
        }
    }

    // Update the _finalizeLaunch function to emit the DualPoolsCreated event
    function _finalizeLaunch(uint256 launchId) internal {
        LaunchInfo storage launch = launches[launchId];
        launch.launched = true;

        LaunchToken token = LaunchToken(launch.tokenAddress);

        // Calculate pool configurations
        PoolConfig memory pools = _calculatePoolAmounts(launch);

        // Create pools
        launch.memeKubPair = _createKubPool(launch.tokenAddress, pools.kubAmount);

        if (launch.ponderCollected > 0) {
            launch.memePonderPair = _createPonderPool(
                launch.tokenAddress,
                pools.ponderAmount,
                pools.tokenAmount
            );

            // Burn PONDER portion
            uint256 ponderToBurn = (launch.ponderCollected * PONDER_TO_BURN) / BASIS_POINTS;
            ponder.burn(ponderToBurn);
            emit PonderBurned(launchId, ponderToBurn);
        }

        // Emit pool creation event
        emit DualPoolsCreated(
            launchId,
            launch.memeKubPair,
            launch.memePonderPair,
            pools.kubAmount,
            pools.ponderAmount
        );

        // Enable trading
        token.setPairs(launch.memeKubPair, launch.memePonderPair);
        token.enableTransfers();

        // Set LP unlock time
        launch.lpUnlockTime = block.timestamp + LP_LOCK_PERIOD;

        emit LaunchCompleted(launchId, launch.kubCollected, launch.ponderCollected);
    }

    function _calculatePoolAmounts(LaunchInfo memory launch) internal pure returns (PoolConfig memory pools) {
        pools.kubAmount = (launch.kubCollected * KUB_TO_MEME_KUB_LP) / BASIS_POINTS;
        pools.ponderAmount = (launch.ponderCollected * PONDER_TO_MEME_PONDER) / BASIS_POINTS;
        pools.tokenAmount = (pools.kubAmount * 555_555_555) / 5555;
        return pools;
    }

    // Update _getPonderValue function to check for price staleness
    function _getPonderValue(uint256 amount) internal view returns (uint256) {
        address ponderKubPair = factory.getPair(address(ponder), router.WETH());

        // Get the last update timestamp from the pair
        (, , uint32 lastUpdateTime) = PonderPair(ponderKubPair).getReserves();

        // Check for price staleness
        if (block.timestamp - lastUpdateTime > PRICE_STALENESS_THRESHOLD) {
            revert StalePrice();
        }

        return priceOracle.getCurrentPrice(ponderKubPair, address(ponder), amount);
    }

    function _createKubPool(address tokenAddress, uint256 kubAmount) internal returns (address) {
        uint256 tokenAmount = (kubAmount * 555_555_555) / 5555;
        address pair = factory.createPair(tokenAddress, router.WETH());

        LaunchToken(tokenAddress).approve(address(router), tokenAmount);

        router.addLiquidityETH{value: kubAmount}(
            tokenAddress,
            tokenAmount,
            tokenAmount * 99 / 100,
            kubAmount * 99 / 100,
            address(this),
            block.timestamp + 1 hours
        );

        return pair;
    }

    function _createPonderPool(
        address tokenAddress,
        uint256 ponderAmount,
        uint256 tokenAmount
    ) internal returns (address) {
        address pair = factory.createPair(tokenAddress, address(ponder));

        LaunchToken(tokenAddress).approve(address(router), tokenAmount);
        ponder.approve(address(router), ponderAmount);

        router.addLiquidity(
            tokenAddress,
            address(ponder),
            tokenAmount,
            ponderAmount,
            tokenAmount * 99 / 100,
            ponderAmount * 99 / 100,
            address(this),
            block.timestamp + 1 hours
        );

        return pair;
    }

    function withdrawLP(uint256 launchId) external {
        LaunchInfo storage launch = launches[launchId];
        if(msg.sender != launch.creator) revert Unauthorized();
        if(block.timestamp < launch.lpUnlockTime) revert LPStillLocked();

        if (launch.memeKubPair != address(0)) {
            _withdrawPairLP(launch.memeKubPair, launch.creator);
        }

        if (launch.memePonderPair != address(0)) {
            _withdrawPairLP(launch.memePonderPair, launch.creator);
        }

        emit LPTokensWithdrawn(launchId, launch.creator, block.timestamp);
    }

    function _withdrawPairLP(address pair, address recipient) internal {
        uint256 balance = PonderERC20(pair).balanceOf(address(this));
        if (balance > 0) {
            PonderERC20(pair).transfer(recipient, balance);
        }
    }

    /**
   * @notice Gets pool information for a launch
     * @param launchId The ID of the launch to query
     * @return memeKubPair Address of the launch token/KUB pair
     * @return memePonderPair Address of the launch token/PONDER pair
     * @return hasSecondaryPool Whether the launch has a PONDER pool
     */
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

    function _validateTokenParams(string memory name, string memory symbol) internal pure {
        bytes memory nameBytes = bytes(name);
        bytes memory symbolBytes = bytes(symbol);
        if(nameBytes.length == 0 || nameBytes.length > 32) revert InvalidTokenParams();
        if(symbolBytes.length == 0 || symbolBytes.length > 8) revert InvalidTokenParams();
    }


    /**
     * @notice Gets contribution details for a launch
     * @param launchId The ID of the launch to query
     * @return kubCollected Amount of KUB directly contributed
     * @return ponderCollected Amount of PONDER contributed
     * @return ponderValueCollected KUB value of PONDER contributions
     * @return totalValue Total value collected (KUB + PONDER value)
     */
    function getContributionInfo(uint256 launchId) external view returns (
        uint256 kubCollected,
        uint256 ponderCollected,
        uint256 ponderValueCollected,
        uint256 totalValue
    ) {
        LaunchInfo storage launch = launches[launchId];
        return (
            launch.kubCollected,
            launch.ponderCollected,
            launch.ponderValueCollected,
            launch.kubCollected + launch.ponderValueCollected
        );
    }

    receive() external payable {}
}

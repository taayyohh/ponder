// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../core/PonderERC20.sol";
import "../interfaces/IPonderFactory.sol";
import "../interfaces/IPonderRouter.sol";
import "../interfaces/ILauncher.sol";


/// @title LaunchToken
/// @notice ERC20 token with creator vesting and fee mechanics for 555 launches
contract LaunchToken is PonderERC20 {
    /// @notice Contract states
    bool public initialized;
    address public launcher;
    bool public transfersEnabled;
    string internal tokenName;
    string internal tokenSymbol;

    /// @notice Core protocol contracts
    IPonderFactory public factory;
    IPonderRouter public router;

    /// @notice Creator vesting configuration
    address public creator;
    uint256 public vestingStart;
    uint256 public vestingEnd;
    uint256 public totalVestedAmount;
    uint256 public vestedClaimed;
    uint256 public constant VESTING_DURATION = 180 days;

    /// @notice Fee configuration (0.1% creator fee on swaps)
    uint256 public constant CREATOR_SWAP_FEE = 10; // 0.1% (10/10000)
    uint256 public constant FEE_DENOMINATOR = 10000;

    /// @notice Events
    event VestingInitialized(address indexed creator, uint256 amount, uint256 startTime, uint256 endTime);
    event TokensClaimed(address indexed creator, uint256 amount);
    event CreatorFeePaid(address indexed creator, uint256 amount);
    event TransfersEnabled();

    /// @notice Errors
    error NotInitialized();
    error AlreadyInitialized();
    error TransfersDisabled();
    error Unauthorized();
    error InsufficientAllowance();
    error NoTokensAvailable();
    error VestingNotStarted();

    modifier onlyLauncher() {
        if (msg.sender != launcher) revert Unauthorized();
        _;
    }

    constructor() PonderERC20("", "") {}

    function name() public view override returns (string memory) {
        return tokenName;
    }

    function symbol() public view override returns (string memory) {
        return tokenSymbol;
    }

    function initialize(
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 totalSupply,
        address _launcher
    ) external {
        if (initialized) revert AlreadyInitialized();

        initialized = true;
        launcher = _launcher;
        tokenName = _tokenName;
        tokenSymbol = _tokenSymbol;

        // Get protocol addresses from launcher
        ILauncher launcherContract = ILauncher(_launcher);
        factory = IPonderFactory(launcherContract.factory());
        router = IPonderRouter(launcherContract.router());

        _mint(_launcher, totalSupply);
    }

    /// @notice Setup vesting schedule for creator tokens
    /// @param _creator Address of the creator
    /// @param _amount Amount of tokens to vest
    function setupVesting(address _creator, uint256 _amount) external onlyLauncher {
        creator = _creator;
        totalVestedAmount = _amount;
        vestingStart = block.timestamp;
        vestingEnd = block.timestamp + VESTING_DURATION;

        emit VestingInitialized(_creator, _amount, vestingStart, vestingEnd);
    }

    /// @notice Allow creator to claim vested tokens
    function claimVestedTokens() external {
        if (msg.sender != creator) revert Unauthorized();
        if (block.timestamp < vestingStart) revert VestingNotStarted();

        uint256 vestedAmount = _calculateVestedAmount();
        if (vestedAmount == 0) revert NoTokensAvailable();

        vestedClaimed += vestedAmount;
        _transfer(launcher, creator, vestedAmount);

        emit TokensClaimed(creator, vestedAmount);
    }

    /// @notice Calculate amount of tokens vested at current time
    function _calculateVestedAmount() internal view returns (uint256) {
        if (block.timestamp < vestingStart) return 0;

        uint256 elapsed = block.timestamp - vestingStart;
        if (elapsed > VESTING_DURATION) {
            elapsed = VESTING_DURATION;
        }

        uint256 vestedAmount = (totalVestedAmount * elapsed) / VESTING_DURATION;
        if (vestedAmount <= vestedClaimed) return 0;

        return vestedAmount - vestedClaimed;
    }

    /// @notice Enable token transfers (called after successful launch)
    function enableTransfers() external onlyLauncher {
        transfersEnabled = true;
        emit TransfersEnabled();
    }

    /// @notice Validate transfer permissions
    modifier checkTransfer(address from) {
        if (!transfersEnabled && from != launcher) revert TransfersDisabled();
        _;
    }

    function transfer(
        address to,
        uint256 value
    ) external override checkTransfer(msg.sender) returns (bool) {
        _transferWithFee(msg.sender, to, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external override checkTransfer(from) returns (bool) {
        uint256 currentAllowance = allowance(from, msg.sender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) revert InsufficientAllowance();
            _approve(from, msg.sender, currentAllowance - value);
        }
        _transferWithFee(from, to, value);
        return true;
    }

    /// @notice Handle transfer with creator fee
    function _transferWithFee(address from, address to, uint256 amount) internal {
        // Only apply fee for swap transfers (to/from LP)
        if (transfersEnabled && _isSwapTransfer(from, to)) {
            uint256 feeAmount = (amount * CREATOR_SWAP_FEE) / FEE_DENOMINATOR;
            uint256 netAmount = amount - feeAmount;

            _transfer(from, creator, feeAmount);
            _transfer(from, to, netAmount);

            emit CreatorFeePaid(creator, feeAmount);
        } else {
            _transfer(from, to, amount);
        }
    }

    /// @notice Check if transfer is a swap (involves LP)
    function _isSwapTransfer(address from, address to) internal view returns (bool) {
        // Check if transfer involves the LP pair
        address pair = factory.getPair(address(this), router.WETH());
        return (from == pair || to == pair);
    }

    /// @notice Get current vesting info
    function getVestingInfo() external view returns (
        uint256 total,
        uint256 claimed,
        uint256 available,
        uint256 start,
        uint256 end
    ) {
        return (
            totalVestedAmount,
            vestedClaimed,
            _calculateVestedAmount(),
            vestingStart,
            vestingEnd
        );
    }
}

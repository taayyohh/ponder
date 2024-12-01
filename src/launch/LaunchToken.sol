// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../core/PonderERC20.sol";
import "../interfaces/IPonderFactory.sol";
import "../interfaces/IPonderRouter.sol";

/**
 * @title LaunchToken
 * @notice ERC20 token with built-in vesting and trading fee mechanics for fair launches
 * @dev Extends PonderERC20 with creator fee and vesting functionality
 */
contract LaunchToken is PonderERC20 {
    /// @notice Core protocol addresses
    address public immutable launcher;
    IPonderFactory public immutable factory;
    IPonderRouter public immutable router;

    /// @notice Trading state
    bool public transfersEnabled;

    /// @notice Creator vesting configuration
    address public creator;
    uint256 public vestingStart;
    uint256 public vestingEnd;
    uint256 public totalVestedAmount;
    uint256 public vestedClaimed;

    /// @notice Protocol constants
    uint256 public constant TOTAL_SUPPLY = 555_555_555 ether;
    uint256 public constant VESTING_DURATION = 180 days;
    uint256 public constant CREATOR_SWAP_FEE = 10; // 0.1%
    uint256 public constant FEE_DENOMINATOR = 10000;

    /// @notice Events
    event VestingInitialized(address indexed creator, uint256 amount, uint256 startTime, uint256 endTime);
    event TokensClaimed(address indexed creator, uint256 amount);
    event CreatorFeePaid(address indexed creator, uint256 amount);
    event TransfersEnabled();

    /// @notice Custom errors
    error TransfersDisabled();
    error Unauthorized();
    error InsufficientAllowance();
    error NoTokensAvailable();
    error VestingNotStarted();

    /**
     * @notice Initializes the token with required parameters
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _launcher Address of the launcher contract
     * @param _factory Address of the factory contract
     * @param _router Address of the router contract
     */
    constructor(
        string memory _name,
        string memory _symbol,
        address _launcher,
        address _factory,
        address payable _router
    ) PonderERC20(_name, _symbol) {
        launcher = _launcher;
        factory = IPonderFactory(_factory);
        router = IPonderRouter(_router);

        // Mint entire supply to launcher
        _mint(_launcher, TOTAL_SUPPLY);
    }
    /**
     * @notice Sets up vesting schedule for creator tokens
     * @param _creator Address of the creator
     * @param _amount Amount of tokens to vest
     */
    function setupVesting(address _creator, uint256 _amount) external {
        if (msg.sender != launcher) revert Unauthorized();
        creator = _creator;
        totalVestedAmount = _amount;
        vestingStart = block.timestamp;
        vestingEnd = block.timestamp + VESTING_DURATION;
        emit VestingInitialized(_creator, _amount, vestingStart, vestingEnd);
    }

    /**
     * @notice Enables token transfers after launch completion
     */
    function enableTransfers() external {
        if (msg.sender != launcher) revert Unauthorized();
        transfersEnabled = true;
        emit TransfersEnabled();
    }

    /**
     * @notice Claims vested tokens for the creator
     */
    function claimVestedTokens() external {
        if (msg.sender != creator) revert Unauthorized();
        if (block.timestamp < vestingStart) revert VestingNotStarted();

        uint256 vestedAmount = _calculateVestedAmount();
        if (vestedAmount == 0) revert NoTokensAvailable();

        vestedClaimed += vestedAmount;
        _transfer(launcher, creator, vestedAmount);

        emit TokensClaimed(creator, vestedAmount);
    }

    /**
     * @notice Override of ERC20 transfer with fee mechanics
     * @param to Recipient address
     * @param value Amount to transfer
     * @return success Transfer success
     */
    function transfer(address to, uint256 value) external override returns (bool) {
        if (!transfersEnabled && msg.sender != launcher) revert TransfersDisabled();
        _transferWithFee(msg.sender, to, value);
        return true;
    }

    /**
     * @notice Override of ERC20 transferFrom with fee mechanics
     * @param from Sender address
     * @param to Recipient address
     * @param value Amount to transfer
     * @return success Transfer success
     */
    function transferFrom(address from, address to, uint256 value) external override returns (bool) {
        if (!transfersEnabled && from != launcher) revert TransfersDisabled();

        uint256 currentAllowance = allowance(from, msg.sender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) revert InsufficientAllowance();
            _approve(from, msg.sender, currentAllowance - value);
        }

        _transferWithFee(from, to, value);
        return true;
    }

    /**
     * @notice Internal function to handle transfers with creator fee
     * @param from Sender address
     * @param to Recipient address
     * @param amount Amount to transfer
     */
    function _transferWithFee(address from, address to, uint256 amount) internal {
        address pair = factory.getPair(address(this), router.WETH());
        bool isSwap = (from == pair || to == pair) && transfersEnabled;

        if (isSwap && from != pair) {  // Only take fee when selling
            uint256 feeAmount = (amount * CREATOR_SWAP_FEE) / FEE_DENOMINATOR;
            uint256 netAmount = amount - feeAmount;


            // Transfer fee to creator
            _transfer(from, creator, feeAmount);
            // Transfer rest to pair
            _transfer(from, to, netAmount);

            emit CreatorFeePaid(creator, feeAmount);
        } else {
            _transfer(from, to, amount);
        }
    }
    /**
     * @notice Calculate current claimable vested amount
     * @return amount Amount of tokens currently claimable
     */
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

    /**
     * @notice Get current vesting information
     * @return total Total amount being vested
     * @return claimed Amount already claimed
     * @return available Amount currently available to claim
     * @return start Vesting start timestamp
     * @return end Vesting end timestamp
     */
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

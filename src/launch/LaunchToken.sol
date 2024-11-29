// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../core/PonderERC20.sol";

/// @title LaunchToken
/// @notice Implementation of ERC20 token with transfer restrictions for fair launches
/// @dev Extends PonderERC20 with initialization and transfer control mechanisms
contract LaunchToken is PonderERC20 {
    /// @notice Whether the token has been initialized
    bool public initialized;

    /// @notice Address of the launcher contract that deployed this token
    address public launcher;

    /// @notice Whether transfers are enabled (after launch)
    bool public transfersEnabled;

    /// @notice Name and symbol to override parent
    string internal tokenName;
    string internal tokenSymbol;

    error NotInitialized();
    error AlreadyInitialized();
    error TransfersDisabled();
    error Unauthorized();
    error InsufficientAllowance();

    /// @notice Ensures caller is the launcher contract
    modifier onlyLauncher() {
        if (msg.sender != launcher) revert Unauthorized();
        _;
    }

    /// @notice Creates token with empty name/symbol
    constructor() PonderERC20("", "") {}

    /// @notice Returns the name of the token
    function name() public view override returns (string memory) {
        return tokenName;
    }

    /// @notice Returns the symbol of the token
    function symbol() public view override returns (string memory) {
        return tokenSymbol;
    }

    /// @notice Initializes the token with its parameters
    /// @param _tokenName Name of the token
    /// @param _tokenSymbol Symbol of the token
    /// @param totalSupply Total supply to mint
    /// @param _launcher Address of the launcher contract
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

        _mint(_launcher, totalSupply);
    }

    /// @notice Enables transfers after liquidity is added
    function enableTransfers() external onlyLauncher {
        transfersEnabled = true;
    }

    /// @notice Validates transfer permissions
    modifier checkTransfer(address from) {
        if (!transfersEnabled && from != launcher) revert TransfersDisabled();
        _;
    }

    /// @notice Overrides ERC20 transfer with transfer restrictions
    /// @param to Address to transfer to
    /// @param value Amount to transfer
    /// @return success True if transfer succeeded
    function transfer(
        address to,
        uint256 value
    ) external override checkTransfer(msg.sender) returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /// @notice Overrides ERC20 transferFrom with transfer restrictions
    /// @param from Address to transfer from
    /// @param to Address to transfer to
    /// @param value Amount to transfer
    /// @return success True if transfer succeeded
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external override checkTransfer(from) returns (bool) {
        uint256 currentAllowance = super.allowance(from, msg.sender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) revert InsufficientAllowance();
            _approve(from, msg.sender, currentAllowance - value);
        }
        _transfer(from, to, value);
        return true;
    }
}

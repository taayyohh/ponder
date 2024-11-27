// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./PonderERC20.sol";

contract PonderToken is PonderERC20 {
    /// @notice Address with minting privileges
    address public minter;

    /// @notice Total cap on token supply
    uint256 public constant MAXIMUM_SUPPLY = 1_000_000_000e18; // 1 billion PONDER

    /// @notice Time after which minting is disabled forever (4 years in seconds)
    uint256 public constant MINTING_END = 4 * 365 days;

    /// @notice Timestamp when token was deployed
    uint256 public immutable deploymentTime;

    /// @notice Address that can set the minter
    address public owner;

    /// @notice Future owner in 2-step transfer
    address public pendingOwner;

    error Forbidden();
    error MintingDisabled();
    error SupplyExceeded();
    error ZeroAddress();

    event MinterUpdated(address indexed previousMinter, address indexed newMinter);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner {
        if (msg.sender != owner) revert Forbidden();
        _;
    }

    modifier onlyMinter {
        if (msg.sender != minter) revert Forbidden();
        _;
    }

    constructor() PonderERC20("Ponder", "PONDER") {
        owner = msg.sender;
        deploymentTime = block.timestamp;
    }

    /// @notice Mint new tokens, capped by maximum supply
    /// @param to Address to receive tokens
    /// @param amount Amount of tokens to mint
    function mint(address to, uint256 amount) external onlyMinter {
        if (block.timestamp > deploymentTime + MINTING_END) revert MintingDisabled();
        if (totalSupply() + amount > MAXIMUM_SUPPLY) revert SupplyExceeded();
        _mint(to, amount);
    }

    /// @notice Update minting privileges
    /// @param _minter New minter address
    function setMinter(address _minter) external onlyOwner {
        if (_minter == address(0)) revert ZeroAddress();
        address oldMinter = minter;
        minter = _minter;
        emit MinterUpdated(oldMinter, _minter);
    }

    /// @notice Begin ownership transfer process
    /// @param newOwner New owner address
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    /// @notice Complete ownership transfer process
    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert Forbidden();
        address oldOwner = owner;
        owner = pendingOwner;
        pendingOwner = address(0);
        emit OwnershipTransferred(oldOwner, owner);
    }
}

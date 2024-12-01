// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IERC20.sol";
import "../interfaces/IWETH.sol";

interface IKYC {
    /// @notice Fetches the KYC level of an address
    /// @param _addr The address to check
    /// @return The KYC level of the given address
    function kycsLevel(address _addr) external view returns (uint256);
}

interface IKKUB is IWETH {
    /// @notice Checks if an address is blacklisted
    /// @param addr The address to check
    /// @return True if the address is blacklisted, false otherwise
    function blacklist(address addr) external view returns (bool);
}

/**
 * @title KKUBUnwrapper
 * @notice This contract un-wraps KKUB tokens into native KUB for compliant users on the Bitkub Chain.
 * @dev The contract ensures that only KYC-compliant addresses can interact with it and includes emergency withdrawal functions to recover stuck funds.
 */
contract KKUBUnwrapper {
    /// @notice The address of the KKUB token
    address public immutable KKUB;

    /// @notice The owner of the contract
    address public owner;

    /// @notice The address of the pending new owner
    address public pendingOwner;

    /// @notice Thrown when a caller is not the owner
    error NotOwner();

    /// @notice Thrown when a token or fund transfer fails
    error TransferFailed();

    /// @notice Thrown when a caller is not the pending owner
    error NotPendingOwner();

    /// @notice Thrown when an address is blacklisted
    error BlacklistedAddress();

    /// @notice Thrown when a caller's KYC level is insufficient
    error InsufficientKYCLevel();

    /// @notice Thrown when a zero address is provided
    error ZeroAddress();

    /// @notice Emitted when KKUB is successfully unwrapped into KUB
    /// @param recipient The recipient of the unwrapped KUB
    /// @param amount The amount of KUB unwrapped
    event UnwrappedKKUB(address indexed recipient, uint256 amount);

    /// @notice Emitted when ownership is transferred
    /// @param previousOwner The previous owner
    /// @param newOwner The new owner
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice Emitted when native KUB is withdrawn in an emergency
    /// @param amount The amount of KUB withdrawn
    event EmergencyWithdraw(uint256 amount);

    /// @notice Emitted when ERC-20 tokens are withdrawn in an emergency
    /// @param token The address of the token withdrawn
    /// @param amount The amount of tokens withdrawn
    event EmergencyWithdrawTokens(address indexed token, uint256 amount);

    /// @dev Modifier to restrict function access to the contract owner
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /**
     * @notice Initializes the contract with the KKUB token address
     * @param _KKUB The address of the KKUB token
     * @dev The owner is set to the deployer of the contract
     */
    constructor(address _KKUB) {
        if (_KKUB == address(0)) revert ZeroAddress();
        KKUB = _KKUB;
        owner = msg.sender;
    }

    /**
     * @notice Unwraps KKUB into native KUB and sends it to the recipient
     * @param amount The amount of KKUB to unwrap
     * @param recipient The address to receive the unwrapped KUB
     * @return True if the operation is successful
     * @dev Ensures both the sender and recipient are not blacklisted
     */
    function unwrapKKUB(uint256 amount, address recipient) external returns (bool) {
        if (IKKUB(KKUB).blacklist(msg.sender) || IKKUB(KKUB).blacklist(recipient)) {
            revert BlacklistedAddress();
        }

        bool success = IWETH(KKUB).transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        IWETH(KKUB).withdraw(amount);

        (success, ) = recipient.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit UnwrappedKKUB(recipient, amount);
        return true;
    }

    /**
     * @notice Transfers ownership to a new address
     * @param newOwner The address of the new owner
     * @dev The new owner must call `acceptOwnership` to complete the transfer
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        pendingOwner = newOwner;
    }

    /**
     * @notice Accepts ownership of the contract
     * @dev Can only be called by the pending owner
     */
    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert NotPendingOwner();
        emit OwnershipTransferred(owner, msg.sender);
        owner = msg.sender;
        pendingOwner = address(0);
    }

    /**
     * @notice Withdraws all native KUB in an emergency
     * @dev Can only be called by the owner
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 amount = address(this).balance;
        (bool success, ) = owner.call{value: amount}("");
        if (!success) revert TransferFailed();
        emit EmergencyWithdraw(amount);
    }

    /**
     * @notice Withdraws all ERC-20 tokens in an emergency
     * @param token The address of the ERC-20 token
     * @dev Can only be called by the owner
     */
    function emergencyWithdrawTokens(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        bool success = IERC20(token).transfer(owner, balance);
        if (!success) revert TransferFailed();
        emit EmergencyWithdrawTokens(token, balance);
    }

    /**
     * @notice Receives native KUB sent directly to the contract
     * @dev This function enables the contract to receive KUB
     */
    receive() external payable {}
}

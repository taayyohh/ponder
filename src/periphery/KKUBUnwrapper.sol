// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IERC20.sol";
import "../interfaces/IWETH.sol";

interface IKYC {
    function kycsLevel(address _addr) external view returns (uint256);
}

interface IKKUB is IWETH {
    function blacklist(address addr) external view returns (bool);
}

contract KKUBUnwrapper {
    address public immutable KKUB;
    address public owner;
    address public pendingOwner;

    error NotOwner();
    error TransferFailed();
    error NotPendingOwner();
    error BlacklistedAddress();
    error InsufficientKYCLevel();
    error ZeroAddress();

    event UnwrappedKKUB(address indexed recipient, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event EmergencyWithdraw(uint256 amount);
    event EmergencyWithdrawTokens(address indexed token, uint256 amount);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address _KKUB) {
        if (_KKUB == address(0)) revert ZeroAddress();
        KKUB = _KKUB;
        owner = msg.sender;
    }

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

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        pendingOwner = newOwner;
    }

    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert NotPendingOwner();
        emit OwnershipTransferred(owner, msg.sender);
        owner = msg.sender;
        pendingOwner = address(0);
    }

    function emergencyWithdraw() external onlyOwner {
        uint256 amount = address(this).balance;
        (bool success,) = owner.call{value: amount}("");
        if (!success) revert TransferFailed();
        emit EmergencyWithdraw(amount);
    }

    function emergencyWithdrawTokens(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        bool success = IERC20(token).transfer(owner, balance);
        if (!success) revert TransferFailed();
        emit EmergencyWithdrawTokens(token, balance);
    }

    receive() external payable {}
}
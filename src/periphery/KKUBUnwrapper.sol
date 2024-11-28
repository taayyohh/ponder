// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IERC20.sol";
import "../interfaces/IWETH.sol";

contract KKUBUnwrapper {
    address public immutable KKUB;
    address public owner;
    address public pendingOwner;

    error NotOwner();
    error TransferFailed();
    error NotPendingOwner();

    event UnwrappedKKUB(address indexed user, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address _KKUB) {
        KKUB = _KKUB;
        owner = msg.sender;
    }

    function unwrapKKUB(uint256 amount, address recipient) external returns (bool) {
        if (!IERC20(KKUB).transferFrom(msg.sender, address(this), amount)) {
            revert TransferFailed();
        }

        IWETH(KKUB).withdraw(amount);

        (bool success,) = recipient.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit UnwrappedKKUB(recipient, amount);
        return true;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        pendingOwner = newOwner;
    }

    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert NotPendingOwner();
        emit OwnershipTransferred(owner, msg.sender);
        owner = msg.sender;
        pendingOwner = address(0);
    }

    function emergencyWithdraw() external onlyOwner {
        (bool success,) = owner.call{value: address(this).balance}("");
        if (!success) revert TransferFailed();
    }

    function emergencyWithdrawTokens(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (!IERC20(token).transfer(owner, balance)) {
            revert TransferFailed();
        }
    }

    receive() external payable {}
}

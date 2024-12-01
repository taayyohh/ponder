// test/mocks/WETH9.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../src/interfaces/IWETH.sol";

contract MockKKUBUnwrapper {
    IWETH public immutable WETH;

    constructor(address _weth) {
        WETH = IWETH(_weth);
    }

    function unwrapKKUB(uint256 amount, address recipient) external returns (bool) {
        // Transfer WETH from sender to this contract
        WETH.transferFrom(msg.sender, address(this), amount);
        // Withdraw ETH from WETH
        WETH.withdraw(amount);
        // Send ETH to recipient
        payable(recipient).transfer(amount);
        return true;
    }

    receive() external payable {}
}

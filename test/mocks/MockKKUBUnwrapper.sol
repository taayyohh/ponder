// test/mocks/WETH9.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MockKKUBUnwrapper {
    function unwrapKKUB(uint256 amount, address recipient) external returns (bool) {
        return true;
    }
}

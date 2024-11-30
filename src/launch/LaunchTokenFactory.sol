// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./LaunchToken.sol";

contract LaunchTokenFactory {
    function deployToken() external returns (address) {
        return address(new LaunchToken());
    }
}

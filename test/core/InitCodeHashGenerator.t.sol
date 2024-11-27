// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/core/PonderPair.sol";

contract InitCodeHashGenerator is Test {
    function testGenerateInitCodeHash() public {
        bytes memory bytecode = type(PonderPair).creationCode;
        bytes32 hash = keccak256(abi.encodePacked(bytecode));
        console.logBytes32(hash);
    }
}
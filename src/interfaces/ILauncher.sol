// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ILauncher {
    function factory() external view returns (address);
    function router() external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IPonderFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);
    event SafeguardUpdated(address indexed safeguard);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function migrator() external view returns (address);
    function safeguard() external view returns (address);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);
    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
    function setMigrator(address) external;
    function setSafeguard(address) external;
}

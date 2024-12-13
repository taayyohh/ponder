// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IPonderFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);
    event LauncherUpdated(address indexed oldLauncher, address indexed newLauncher);
    event StakingContractUpdated(address indexed oldStaking, address indexed newStaking);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function migrator() external view returns (address);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
    function setMigrator(address) external;
    function launcher() external view returns (address);
    function setLauncher(address) external;
    function stakingContract() external view returns (address);
    function setStakingContract(address) external;
}

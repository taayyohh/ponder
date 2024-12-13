// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IPonderFactory.sol";
import "./PonderPair.sol";

contract PonderFactory is IPonderFactory {
    address public feeTo;
    address public feeToSetter;
    address public migrator;
    address public launcher;
    address public stakingContract;

    // Immutable addresses needed for pair creation
    address public immutable stablecoin;
    address public immutable router;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    error IdenticalAddresses();
    error ZeroAddress();
    error PairExists();
    error Forbidden();

    bytes32 public constant INIT_CODE_PAIR_HASH = keccak256(type(PonderPair).creationCode);

    constructor(
        address _feeToSetter,
        address _launcher,
        address _stablecoin,
        address _router
    ) {
        if (_feeToSetter == address(0)) revert ZeroAddress();
        if (_stablecoin == address(0)) revert ZeroAddress();
        if (_router == address(0)) revert ZeroAddress();

        feeToSetter = _feeToSetter;
        launcher = _launcher;
        stablecoin = _stablecoin;
        router = _router;
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        if (tokenA == tokenB) revert IdenticalAddresses();
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (token0 == address(0)) revert ZeroAddress();
        if (getPair[token0][token1] != address(0)) revert PairExists();

        // Create the pair with stablecoin and router addresses
        bytes memory bytecode = type(PonderPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        PonderPair(pair).initialize(token0, token1);

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        if (msg.sender != feeToSetter) revert Forbidden();
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        if (msg.sender != feeToSetter) revert Forbidden();
        feeToSetter = _feeToSetter;
    }

    function setMigrator(address _migrator) external {
        if (msg.sender != feeToSetter) revert Forbidden();
        migrator = _migrator;
    }

    function setLauncher(address _launcher) external {
        if (msg.sender != feeToSetter) revert Forbidden();
        address oldLauncher = launcher;
        launcher = _launcher;
        emit LauncherUpdated(oldLauncher, _launcher);
    }

    function setStakingContract(address _stakingContract) external {
        if (msg.sender != feeToSetter) revert Forbidden();
        address oldStaking = stakingContract;
        stakingContract = _stakingContract;
        emit StakingContractUpdated(oldStaking, _stakingContract);
    }
}

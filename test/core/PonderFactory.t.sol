// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../mocks/ERC20Mint.sol";
import "../../src/core/PonderFactory.sol";

contract PonderFactoryTest is Test {
    PonderFactory factory;
    ERC20Mint tokenA;
    ERC20Mint tokenB;
    ERC20Mint tokenC;
    ERC20Mint stablecoin;
    address feeToSetter = address(0xfee);
    address initialLauncher = address(0xbad);
    address router = address(0xdead);

    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);
    event LauncherUpdated(address indexed oldLauncher, address indexed newLauncher);
    event StakingContractUpdated(address indexed oldStaking, address indexed newStaking);

    function setUp() public {
        tokenA = new ERC20Mint("Token A", "TKNA");
        tokenB = new ERC20Mint("Token B", "TKNB");
        tokenC = new ERC20Mint("Token C", "TKNC");
        stablecoin = new ERC20Mint("USDT", "USDT");

        factory = new PonderFactory(
            feeToSetter,
            initialLauncher,
            address(stablecoin),
            router
        );
    }

    function testCreatePair() public {
        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);

        // Get the creation code with constructor arguments
        bytes memory constructorArgs = abi.encode(address(stablecoin), router);
        bytes memory bytecode = abi.encodePacked(type(PonderPair).creationCode, constructorArgs);

        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        address expectedPair = address(uint160(uint256(keccak256(abi.encodePacked(
            hex'ff',
            address(factory),
            salt,
            keccak256(bytecode)
        )))));

        vm.expectEmit(true, true, true, true);
        emit PairCreated(token0, token1, expectedPair, 1);

        address pair = factory.createPair(address(tokenA), address(tokenB));

        assertFalse(pair == address(0));
        assertEq(factory.allPairsLength(), 1);
        assertEq(factory.allPairs(0), pair);
        assertEq(factory.getPair(address(tokenA), address(tokenB)), pair);
        assertEq(factory.getPair(address(tokenB), address(tokenA)), pair);

        // Verify pair initialization
        PonderPair pairContract = PonderPair(pair);
        assertEq(address(pairContract.stablecoin()), address(stablecoin));
        assertEq(address(pairContract.router()), router);
        assertEq(pairContract.token0(), token0);
        assertEq(pairContract.token1(), token1);
    }

    function testCreatePairReversed() public {
        // First create pair normally
        address pair1 = factory.createPair(address(tokenA), address(tokenB));

        // Verify pair addresses match regardless of token order
        assertEq(factory.getPair(address(tokenA), address(tokenB)), pair1);
        assertEq(factory.getPair(address(tokenB), address(tokenA)), pair1);

        // Verify tokens are stored in correct order
        PonderPair pairContract = PonderPair(pair1);
        address token0 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token1 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);
        assertEq(pairContract.token0(), token0);
        assertEq(pairContract.token1(), token1);
    }

    function testCreateMultiplePairs() public {
        // Create first pair
        address pair1 = factory.createPair(address(tokenA), address(tokenB));
        assertEq(factory.allPairsLength(), 1);
        assertEq(factory.getPair(address(tokenA), address(tokenB)), pair1);

        // Create second pair
        address pair2 = factory.createPair(address(tokenA), address(tokenC));
        assertEq(factory.allPairsLength(), 2);
        assertEq(factory.getPair(address(tokenA), address(tokenC)), pair2);

        // Create third pair
        address pair3 = factory.createPair(address(tokenB), address(tokenC));
        assertEq(factory.allPairsLength(), 3);
        assertEq(factory.getPair(address(tokenB), address(tokenC)), pair3);

        // Verify all pairs are different
        assertTrue(pair1 != pair2);
        assertTrue(pair2 != pair3);
        assertTrue(pair1 != pair3);
    }

    function testSetStakingContract() public {
        address newStaking = address(0x123);

        vm.prank(feeToSetter);
        vm.expectEmit(true, true, false, true);
        emit StakingContractUpdated(address(0), newStaking);

        factory.setStakingContract(newStaking);
        assertEq(factory.stakingContract(), newStaking);
    }

    function testFailSetStakingContractUnauthorized() public {
        vm.prank(address(0x456));
        factory.setStakingContract(address(0x123));
    }

    function testFactoryInitialization() public {
        assertEq(factory.feeToSetter(), feeToSetter);
        assertEq(factory.launcher(), initialLauncher);
        assertEq(address(factory.stablecoin()), address(stablecoin));
        assertEq(address(factory.router()), router);
    }

    function testFailCreatePairZeroAddress() public {
        factory.createPair(address(0), address(tokenA));
    }

    function testFailCreatePairIdenticalTokens() public {
        factory.createPair(address(tokenA), address(tokenA));
    }

    function testFailCreatePairExistingPair() public {
        factory.createPair(address(tokenA), address(tokenB));
        factory.createPair(address(tokenA), address(tokenB));
    }

    function testSetFeeTo() public {
        address newFeeTo = address(0x1);
        vm.prank(feeToSetter);
        factory.setFeeTo(newFeeTo);
        assertEq(factory.feeTo(), newFeeTo);
    }

    function testFailSetFeeToUnauthorized() public {
        address newFeeTo = address(0x1);
        factory.setFeeTo(newFeeTo);
    }

    function testSetFeeToSetter() public {
        address newFeeToSetter = address(0x1);
        vm.prank(feeToSetter);
        factory.setFeeToSetter(newFeeToSetter);
        assertEq(factory.feeToSetter(), newFeeToSetter);
    }

    function testFailSetFeeToSetterUnauthorized() public {
        address newFeeToSetter = address(0x1);
        factory.setFeeToSetter(newFeeToSetter);
    }

    function testSetMigrator() public {
        address newMigrator = address(0x1);
        vm.prank(feeToSetter);
        factory.setMigrator(newMigrator);
        assertEq(factory.migrator(), newMigrator);
    }

    function testFailSetMigratorUnauthorized() public {
        address newMigrator = address(0x1);
        factory.setMigrator(newMigrator);
    }

    function testSetLauncher() public {
        address newLauncher = address(0x123);
        vm.prank(feeToSetter);
        vm.expectEmit(true, true, false, true);
        emit LauncherUpdated(initialLauncher, newLauncher);
        factory.setLauncher(newLauncher);
        assertEq(factory.launcher(), newLauncher);
    }

    function testFailSetLauncherUnauthorized() public {
        address newLauncher = address(0x123);
        factory.setLauncher(newLauncher);
    }

    function testLauncherInitialization() public {
        assertEq(factory.launcher(), initialLauncher, "Launcher not initialized correctly");
    }

    function testFailZeroAddressStablecoin() public {
        new PonderFactory(
            feeToSetter,
            initialLauncher,
            address(0),  // zero address stablecoin
            router
        );
    }

    function testFailZeroAddressRouter() public {
        new PonderFactory(
            feeToSetter,
            initialLauncher,
            address(stablecoin),
            address(0)  // zero address router
        );
    }

    // Helper function to compute the expected pair address
    function computePairAddress(address token0, address token1) internal view returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(
            hex'ff',
            address(factory),
            keccak256(abi.encodePacked(token0, token1)),
            factory.INIT_CODE_PAIR_HASH()
        )))));
    }
}

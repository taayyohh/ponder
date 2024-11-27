// test/core/PonderSafeguard.t.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/core/PonderSafeguard.sol";
import "../../src/core/PonderFactory.sol";
import "../../src/core/PonderPair.sol";
import "../mocks/ERC20Mint.sol";

contract PonderSafeguardTest is Test {
    PonderSafeguard safeguard;
    PonderFactory factory;
    PonderPair pair;
    ERC20Mint token0;
    ERC20Mint token1;

    address alice = makeAddr("alice");

    function setUp() public {
        // Deploy contracts
        safeguard = new PonderSafeguard();
        factory = new PonderFactory(address(this));

        // Set up safeguard in factory
        factory.setSafeguard(address(safeguard));

        // Deploy tokens
        token0 = new ERC20Mint("Token A", "TKNA");
        token1 = new ERC20Mint("Token B", "TKNB");

        // Create pair
        address pairAddress = factory.createPair(address(token0), address(token1));
        pair = PonderPair(pairAddress);

        // Setup initial liquidity
        vm.startPrank(alice);
        token0.mint(alice, 100e18);
        token1.mint(alice, 100e18);
        token0.transfer(address(pair), 100e18);
        token1.transfer(address(pair), 100e18);
        pair.mint(alice);
        vm.stopPrank();
    }

    function testPriceDeviation() public {
        // Test normal trade
        assertTrue(
            safeguard.checkPriceDeviation(
                address(pair),
                1e18, // amount0Out
                0,    // amount1Out
                0,    // amount0In
                1.1e18 // amount1In
            ),
            "Normal trade should be allowed"
        );

        // Test large price deviation
        assertFalse(
            safeguard.checkPriceDeviation(
                address(pair),
                50e18, // amount0Out
                0,     // amount1Out
                0,     // amount0In
                1e18   // amount1In
            ),
            "Large price deviation should be blocked"
        );
    }

    function testVolumeLimits() public {
        assertTrue(
            safeguard.checkAndUpdateVolume(
                address(pair),
                1e18,
                1e18
            ),
            "Small volume should be allowed"
        );

        vm.warp(block.timestamp + 1 hours);

        assertFalse(
            safeguard.checkAndUpdateVolume(
                address(pair),
                1_000_000e18,
                1_000_000e18
            ),
            "Volume above limit should be blocked"
        );
    }

    function testEmergencyStop() public {
        assertFalse(safeguard.paused(), "Should not be paused initially");

        vm.prank(address(this));
        safeguard.pause();

        assertTrue(safeguard.paused(), "Should be paused");

        vm.prank(address(this));
        safeguard.unpause();

        assertFalse(safeguard.paused(), "Should be unpaused");
    }

    function testOwnershipTransfer() public {
        address newOwner = address(0x123);

        vm.prank(address(this));
        safeguard.transferOwnership(newOwner);

        vm.prank(newOwner);
        safeguard.acceptOwnership();

        assertEq(safeguard.owner(), newOwner);
    }

    function testEmergencyAdmin() public {
        address newAdmin = address(0x456);

        vm.prank(address(this));
        safeguard.setEmergencyAdmin(newAdmin);

        assertEq(safeguard.emergencyAdmin(), newAdmin);

        // Test emergency admin can pause
        vm.prank(newAdmin);
        safeguard.pause();

        assertTrue(safeguard.paused());
    }
}

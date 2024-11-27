// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/core/PonderToken.sol";

contract PonderTokenTest is Test {
    PonderToken token;
    address owner = address(this);
    address alice = address(0x1);
    address bob = address(0x2);

    event MinterUpdated(address indexed previousMinter, address indexed newMinter);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function setUp() public {
        token = new PonderToken();
    }

    function testInitialState() public {
        assertEq(token.name(), "Ponder");
        assertEq(token.symbol(), "PONDER");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 0);
        assertEq(token.owner(), address(this));
        assertEq(token.minter(), address(0));
        assertEq(token.MAXIMUM_SUPPLY(), 1_000_000_000e18);
    }

    function testSetMinter() public {
        vm.expectEmit(true, true, false, false);
        emit MinterUpdated(address(0), alice);
        token.setMinter(alice);
        assertEq(token.minter(), alice);
    }

    function testFailSetMinterUnauthorized() public {
        vm.prank(alice);
        token.setMinter(bob);
    }

    function testMinting() public {
        token.setMinter(address(this));
        token.mint(alice, 1000e18);
        assertEq(token.totalSupply(), 1000e18);
        assertEq(token.balanceOf(alice), 1000e18);
    }

    function testFailMintOverMaxSupply() public {
        token.setMinter(address(this));
        token.mint(alice, token.MAXIMUM_SUPPLY() + 1);
    }

    function testFailMintUnauthorized() public {
        vm.prank(alice);
        token.mint(alice, 1000);
    }

    function testMintingDeadline() public {
        token.setMinter(address(this));

        // Can mint before deadline
        token.mint(alice, 1000e18);

        // Warp to just before deadline
        vm.warp(block.timestamp + 4 * 365 days - 1);
        token.mint(alice, 1000e18);

        // Warp past deadline
        vm.warp(block.timestamp + 2);
        vm.expectRevert(PonderToken.MintingDisabled.selector);
        token.mint(alice, 1000e18);
    }

    function testOwnershipTransfer() public {
        // Start transfer
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferStarted(address(this), alice);
        token.transferOwnership(alice);
        assertEq(token.pendingOwner(), alice);

        // Complete transfer
        vm.prank(alice);
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(address(this), alice);
        token.acceptOwnership();

        assertEq(token.owner(), alice);
        assertEq(token.pendingOwner(), address(0));
    }

    function testFailTransferOwnershipUnauthorized() public {
        vm.prank(alice);
        token.transferOwnership(bob);
    }

    function testFailAcceptOwnershipUnauthorized() public {
        token.transferOwnership(alice);
        vm.prank(bob);
        token.acceptOwnership();
    }

    function testFailZeroAddressOwner() public {
        token.transferOwnership(address(0));
    }

    function testFailZeroAddressMinter() public {
        token.setMinter(address(0));
    }
}

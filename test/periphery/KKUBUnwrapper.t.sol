// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../mocks/WETH9.sol";
import "../../src/periphery/KKUBUnwrapper.sol";

contract KKUBUnwrapperTest is Test {
    KKUBUnwrapper unwrapper;
    WETH9 kkub;
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    event UnwrappedKKUB(address indexed user, uint256 amount);

    function setUp() public {
        kkub = new WETH9();
        unwrapper = new KKUBUnwrapper(address(kkub));
        vm.deal(address(unwrapper), 100 ether);
        vm.deal(alice, 100 ether);
    }

    function testUnwrapKKUB() public {
        uint256 amount = 1 ether;

        vm.startPrank(alice);
        kkub.deposit{value: amount}();
        kkub.approve(address(unwrapper), amount);

        uint256 balanceBefore = alice.balance;

        vm.expectEmit(true, true, false, true);
        emit UnwrappedKKUB(alice, amount);

        unwrapper.unwrapKKUB(amount, alice);
        vm.stopPrank();

        assertEq(alice.balance - balanceBefore, amount, "Incorrect BKC amount received");
        assertEq(kkub.balanceOf(alice), 0, "KKUB not fully unwrapped");
    }

    function testUnwrapKKUBToOtherRecipient() public {
        uint256 amount = 1 ether;

        vm.startPrank(alice);
        kkub.deposit{value: amount}();
        kkub.approve(address(unwrapper), amount);

        uint256 balanceBefore = bob.balance;

        vm.expectEmit(true, true, false, true);
        emit UnwrappedKKUB(bob, amount);

        unwrapper.unwrapKKUB(amount, bob);
        vm.stopPrank();

        assertEq(bob.balance - balanceBefore, amount, "Incorrect BKC amount received");
        assertEq(kkub.balanceOf(alice), 0, "KKUB not fully unwrapped");
    }

    function testFailUnwrapWithoutApproval() public {
        uint256 amount = 1 ether;

        vm.startPrank(alice);
        kkub.deposit{value: amount}();
        unwrapper.unwrapKKUB(amount, alice);
        vm.stopPrank();
    }

    function testFailUnwrapWithInsufficientBalance() public {
        uint256 amount = 1 ether;

        vm.startPrank(alice);
        kkub.approve(address(unwrapper), amount);
        unwrapper.unwrapKKUB(amount, alice);
        vm.stopPrank();
    }

    function testOwnershipTransfer() public {
        address newOwner = makeAddr("newOwner");
        unwrapper.transferOwnership(newOwner);
        assertEq(unwrapper.owner(), address(this), "Ownership should not transfer before acceptance");

        vm.prank(newOwner);
        unwrapper.acceptOwnership();
        assertEq(unwrapper.owner(), newOwner, "Ownership not transferred");
    }

    function testRevertNonOwnerFunctions() public {
        address alice = makeAddr("alice");

        // Test transferOwnership
        vm.prank(alice);
        vm.expectRevert(KKUBUnwrapper.NotOwner.selector);
        unwrapper.transferOwnership(alice);

        // Test emergencyWithdraw
        vm.prank(alice);
        vm.expectRevert(KKUBUnwrapper.NotOwner.selector);
        unwrapper.emergencyWithdraw();

        // Test emergencyWithdrawTokens
        vm.prank(alice);
        vm.expectRevert(KKUBUnwrapper.NotOwner.selector);
        unwrapper.emergencyWithdrawTokens(address(kkub));
    }

    function testEmergencyWithdraw() public {
        uint256 amount = 1 ether;
        vm.deal(address(unwrapper), amount);

        uint256 balanceBefore = address(this).balance;
        unwrapper.emergencyWithdraw();
        assertEq(address(this).balance - balanceBefore, amount, "Emergency withdrawal failed");
    }

    function testEmergencyWithdrawTokens() public {
        uint256 amount = 1 ether;

        vm.startPrank(alice);
        kkub.deposit{value: amount}();
        kkub.transfer(address(unwrapper), amount);
        vm.stopPrank();

        uint256 balanceBefore = kkub.balanceOf(address(this));
        unwrapper.emergencyWithdrawTokens(address(kkub));
        assertEq(kkub.balanceOf(address(this)) - balanceBefore, amount, "Emergency token withdrawal failed");
    }

    receive() external payable {}
}

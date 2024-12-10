// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/launch/LaunchToken.sol";
import "../../src/core/PonderFactory.sol";
import "../../src/core/PonderToken.sol";
import "../../src/periphery/PonderRouter.sol";
import "../mocks/WETH9.sol";
import "../mocks/MockKKUBUnwrapper.sol";

contract LaunchTokenTest is Test {
    LaunchToken token;
    PonderToken ponder;
    PonderFactory factory;
    PonderRouter router;
    WETH9 weth;

    address owner = address(this);
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address creator = makeAddr("creator");
    address feeCollector = makeAddr("feeCollector");
    address treasury = makeAddr("treasury");
    address launcher = makeAddr("launcher");

    uint256 constant INITIAL_LIQUIDITY = 100e18;
    uint256 constant TEST_AMOUNT = 100e18; // Reduced from 1000e18
    uint256 constant FEE_TEST_AMOUNT = 100e18; // Specific amount for fee testing

    event VestingInitialized(address indexed creator, uint256 amount, uint256 startTime, uint256 endTime);
    event TokensClaimed(address indexed creator, uint256 amount);
    event CreatorFeePaid(address indexed creator, uint256 amount, address pair);
    event ProtocolFeePaid(uint256 amount, address pair);
    event TransfersEnabled();
    event PairsSet(address kubPair, address ponderPair);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        // Deploy core contracts
        weth = new WETH9();
        ponder = new PonderToken(treasury, treasury, treasury, launcher);
        factory = new PonderFactory(address(this), launcher);

        MockKKUBUnwrapper unwrapper = new MockKKUBUnwrapper(address(weth));
        router = new PonderRouter(address(factory), address(weth), address(unwrapper));

        // Deploy launch token
        token = new LaunchToken(
            "Test Token",
            "TEST",
            launcher,
            address(factory),
            payable(address(router)),
            address(ponder)
        );

        // Create trading pairs
        address kubPair = factory.createPair(address(token), address(weth));
        address ponderPair = factory.createPair(address(token), address(ponder));

        // Set pairs in token
        vm.prank(launcher);
        token.setPairs(kubPair, ponderPair);

        // Setup vesting
        vm.prank(launcher);
        token.setupVesting(creator, TEST_AMOUNT);

        // Enable transfers
        vm.prank(launcher);
        token.enableTransfers();

        // Setup initial balances
        vm.startPrank(launcher);
        token.transfer(alice, TEST_AMOUNT * 10);
        token.transfer(bob, TEST_AMOUNT * 10);
        vm.stopPrank();
    }

    function testKubPairFees() public {
        address kubPair = token.kubPair();

        // Calculate expected fees
        uint256 protocolFee = (FEE_TEST_AMOUNT * token.KUB_PROTOCOL_FEE()) / token.FEE_DENOMINATOR();
        uint256 creatorFee = (FEE_TEST_AMOUNT * token.KUB_CREATOR_FEE()) / token.FEE_DENOMINATOR();
        uint256 expectedTransfer = FEE_TEST_AMOUNT - protocolFee - creatorFee;

        // Record initial balances
        uint256 launcherBalanceBefore = token.balanceOf(launcher);
        uint256 creatorBalanceBefore = token.balanceOf(creator);
        uint256 pairBalanceBefore = token.balanceOf(kubPair);

        vm.startPrank(alice);
        token.transfer(kubPair, FEE_TEST_AMOUNT);
        vm.stopPrank();

        assertEq(
            token.balanceOf(kubPair) - pairBalanceBefore,
            expectedTransfer,
            "Incorrect transfer amount"
        );
        assertEq(
            token.balanceOf(launcher) - launcherBalanceBefore,
            protocolFee,
            "Incorrect protocol fee"
        );
        assertEq(
            token.balanceOf(creator) - creatorBalanceBefore,
            creatorFee,
            "Incorrect creator fee"
        );
    }

    function testPonderPairFees() public {
        address ponderPair = token.ponderPair();

        // Calculate expected fees
        uint256 protocolFee = (FEE_TEST_AMOUNT * token.PONDER_PROTOCOL_FEE()) / token.FEE_DENOMINATOR();
        uint256 creatorFee = (FEE_TEST_AMOUNT * token.PONDER_CREATOR_FEE()) / token.FEE_DENOMINATOR();
        uint256 expectedTransfer = FEE_TEST_AMOUNT - protocolFee - creatorFee;

        // Record initial balances
        uint256 launcherBalanceBefore = token.balanceOf(launcher);
        uint256 creatorBalanceBefore = token.balanceOf(creator);
        uint256 pairBalanceBefore = token.balanceOf(ponderPair);

        vm.startPrank(alice);
        token.transfer(ponderPair, FEE_TEST_AMOUNT);
        vm.stopPrank();

        assertEq(
            token.balanceOf(ponderPair) - pairBalanceBefore,
            expectedTransfer,
            "Incorrect transfer amount"
        );
        assertEq(
            token.balanceOf(launcher) - launcherBalanceBefore,
            protocolFee,
            "Incorrect protocol fee"
        );
        assertEq(
            token.balanceOf(creator) - creatorBalanceBefore,
            creatorFee,
            "Incorrect creator fee"
        );
    }

    function testVestingClaim() public {
        uint256 vestAmount = TEST_AMOUNT;

        vm.prank(launcher);
        token.setupVesting(creator, vestAmount);

        // Move to middle of vesting period
        vm.warp(block.timestamp + 90 days);

        vm.startPrank(creator);
        uint256 expectedClaim = vestAmount / 2;
        vm.expectEmit(true, false, false, true);
        emit TokensClaimed(creator, expectedClaim);
        token.claimVestedTokens();
        vm.stopPrank();

        assertEq(token.balanceOf(creator), expectedClaim);
        assertEq(token.vestedClaimed(), expectedClaim);
    }

    function testFailTransfersBeforeEnabled() public {
        LaunchToken newToken = new LaunchToken(
            "New Token",
            "NEW",
            launcher,
            address(factory),
            payable(address(router)),
            address(ponder)
        );

        vm.prank(launcher);
        newToken.transfer(alice, TEST_AMOUNT);

        vm.prank(alice);
        newToken.transfer(bob, TEST_AMOUNT);
    }

    function testGetVestingInfo() public {
        uint256 vestAmount = TEST_AMOUNT;
        uint256 startTime = block.timestamp;

        (
            uint256 total,
            uint256 claimed,
            uint256 available,
            uint256 start,
            uint256 end
        ) = token.getVestingInfo();

        assertEq(total, vestAmount);
        assertEq(claimed, 0);
        assertEq(start, startTime);
        assertEq(end, startTime + token.VESTING_DURATION());
    }

    function testFailSetPairsUnauthorized() public {
        vm.prank(alice);
        token.setPairs(address(0x123), address(0x456));
    }

    function testFailSetPairsTwice() public {
        vm.startPrank(launcher);
        token.setPairs(address(0x123), address(0x456));
        token.setPairs(address(0x789), address(0xabc));
        vm.stopPrank();
    }

    function testInitialState() public {
        assertEq(token.name(), "Test Token");
        assertEq(token.symbol(), "TEST");
        assertEq(token.launcher(), launcher);
        assertEq(address(token.factory()), address(factory));
        assertEq(address(token.router()), address(router));
        assertEq(address(token.ponder()), address(ponder));
        assertEq(token.totalSupply(), token.TOTAL_SUPPLY());
        assertEq(token.balanceOf(launcher), token.TOTAL_SUPPLY() - TEST_AMOUNT * 20);
        assertTrue(token.transfersEnabled());
    }

    receive() external payable {}
}

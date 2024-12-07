// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/launch/LaunchToken.sol";
import "../../src/core/PonderFactory.sol";
import "../../src/core/PonderToken.sol";
import "../../src/periphery/PonderRouter.sol";
import "../../test/mocks/WETH9.sol";
import "../mocks/MockKKUBUnwrapper.sol";

contract LaunchTokenTest is Test {
    LaunchToken token;
    PonderToken ponder;
    PonderFactory factory;
    PonderRouter router;
    WETH9 weth;

    address launcher = address(0x1);
    address creator = address(0x2);
    address user = address(0x3);
    address treasury = address(0x4);

    event VestingInitialized(address indexed creator, uint256 amount, uint256 startTime, uint256 endTime);
    event TokensClaimed(address indexed creator, uint256 amount);
    event CreatorFeePaid(address indexed creator, uint256 amount);
    event ProtocolFeePaid(uint256 amount);
    event TransfersEnabled();

    function setUp() public {
        // Deploy core contracts
        weth = new WETH9();
        factory = new PonderFactory(address(this), launcher);
        MockKKUBUnwrapper unwrapper = new MockKKUBUnwrapper(address(weth));
        router = new PonderRouter(address(factory), address(weth), address(unwrapper));
        ponder = new PonderToken(treasury, treasury, treasury, launcher);

        // Deploy launch token
        token = new LaunchToken(
            "Test Token",
            "TEST",
            launcher,
            address(factory),
            payable(address(router)),
            address(ponder)
        );
    }

    function testInitialState() public {
        assertEq(token.name(), "Test Token");
        assertEq(token.symbol(), "TEST");
        assertEq(token.launcher(), launcher);
        assertEq(address(token.factory()), address(factory));
        assertEq(address(token.router()), address(router));
        assertEq(address(token.ponder()), address(ponder));
        assertEq(token.totalSupply(), token.TOTAL_SUPPLY());
        assertEq(token.balanceOf(launcher), token.TOTAL_SUPPLY());
    }

    function testVestingSetup() public {
        uint256 vestAmount = 1000e18;

        vm.startPrank(launcher);
        vm.expectEmit(true, false, false, true);
        emit VestingInitialized(creator, vestAmount, block.timestamp, block.timestamp + token.VESTING_DURATION());
        token.setupVesting(creator, vestAmount);
        vm.stopPrank();

        assertEq(token.creator(), creator);
        assertEq(token.totalVestedAmount(), vestAmount);
        assertEq(token.vestingStart(), block.timestamp);
        assertEq(token.vestingEnd(), block.timestamp + token.VESTING_DURATION());
    }

    function testFailNonLauncherVestingSetup() public {
        vm.prank(address(0x9));
        token.setupVesting(creator, 1000e18);
    }

    function testVestingClaim() public {
        uint256 vestAmount = 1000e18;

        // Setup vesting
        vm.prank(launcher);
        token.setupVesting(creator, vestAmount);

        // Move halfway through vesting
        vm.warp(block.timestamp + 90 days);

        // Claim tokens
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
        vm.prank(launcher);
        token.transfer(user, 1000e18);

        vm.prank(user);
        token.transfer(address(0x9), 100e18);
    }

    function testTransferAfterEnabled() public {
        vm.startPrank(launcher);
        token.enableTransfers();
        token.transfer(user, 1000e18);
        vm.stopPrank();

        vm.prank(user);
        token.transfer(address(0x9), 100e18);
        assertEq(token.balanceOf(address(0x9)), 100e18);
    }

    function testGetVestingInfo() public {
        uint256 vestAmount = 1000e18;

        // Setup vesting
        vm.prank(launcher);
        token.setupVesting(creator, vestAmount);

        // Move partway through vesting
        vm.warp(block.timestamp + 45 days);

        (
            uint256 total,
            uint256 claimed,
            uint256 available,
            uint256 start,
            uint256 end
        ) = token.getVestingInfo();

        assertEq(total, vestAmount);
        assertEq(claimed, 0);
        assertEq(available, (vestAmount * 45 days) / token.VESTING_DURATION());
        assertEq(start, block.timestamp - 45 days);
        assertEq(end, start + token.VESTING_DURATION());
    }
}

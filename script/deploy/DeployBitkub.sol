// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../src/core/PonderFactory.sol";
import "../../src/core/PonderMasterChef.sol";
import "../../src/core/PonderPriceOracle.sol";
import "../../src/core/PonderToken.sol";
import "../../src/core/PonderStaking.sol";
import "../../src/launch/FiveFiveFiveLauncher.sol";
import "../../src/periphery/KKUBUnwrapper.sol";
import "../../src/periphery/PonderRouter.sol";
import "forge-std/Script.sol";

contract DeployBitkubScript is Script {
    uint256 constant PONDER_PER_SECOND = 3168000000000000000; // 3.168 ether

    address constant USDT = 0x6Cb232F0A9a3aC508233D118ac644888102b40e5;
    address constant KKUB = 0xBa71efd94be63bD47B78eF458DE982fE29f552f7;

    uint256 constant INITIAL_KUB_AMOUNT = 100 ether;
    uint256 constant INITIAL_PONDER_AMOUNT = 2800000 ether;

    error InvalidAddress();
    error PairCreationFailed();
    error DeploymentFailed(string name);
    error LiquidityAddFailed();

    struct DeploymentAddresses {
        address ponder;
        address factory;
        address kkubUnwrapper;
        address router;
        address oracle;
        address ponderKubPair;
        address masterChef;
        address launcher;
        address staking;
    }

    function validateAddresses(
        address treasury,
        address teamReserve,
        address marketing,
        address deployer
    ) internal pure {
        if (treasury == address(0) ||
        teamReserve == address(0) ||
        marketing == address(0) ||
            deployer == address(0)) {
            revert InvalidAddress();
        }
    }

    function deployContracts(
        address deployer,
        address treasury,
        address teamReserve,
        address marketing
    ) internal returns (DeploymentAddresses memory addresses) {
        // First deploy KKUBUnwrapper
        addresses.kkubUnwrapper = address(new KKUBUnwrapper(KKUB));
        _verifyContract("KKUBUnwrapper", addresses.kkubUnwrapper);

        // Deploy factory first since router needs it
        addresses.factory = address(new PonderFactory(
            deployer,
            address(0), // launcher will be set later
            USDT,
            address(0) // router will be created next
        ));
        _verifyContract("PonderFactory", addresses.factory);

        // Now deploy router with factory address
        addresses.router = address(new PonderRouter(
            addresses.factory,
            KKUB,
            addresses.kkubUnwrapper
        ));
        _verifyContract("PonderRouter", addresses.router);

        addresses.ponder = address(new PonderToken(
            treasury,
            teamReserve,
            marketing,
            address(0) // launcher will be set later
        ));
        _verifyContract("PonderToken", addresses.ponder);

        addresses.staking = address(new PonderStaking(
            addresses.ponder,
            USDT
        ));
        _verifyContract("PonderStaking", addresses.staking);

        PonderFactory(addresses.factory).setStakingContract(addresses.staking);
        console.log("Factory staking contract set to:", addresses.staking);

        // Create PONDER/KKUB pair
        PonderFactory(addresses.factory).createPair(addresses.ponder, KKUB);
        addresses.ponderKubPair = PonderFactory(addresses.factory).getPair(addresses.ponder, KKUB);
        if (addresses.ponderKubPair == address(0)) revert PairCreationFailed();

        addresses.oracle = address(new PonderPriceOracle(
            addresses.factory,
            KKUB,
            USDT
        ));
        _verifyContract("PonderPriceOracle", addresses.oracle);

        addresses.launcher = address(new FiveFiveFiveLauncher(
            addresses.factory,
            payable(addresses.router),
            treasury,
            addresses.ponder,
            addresses.oracle
        ));
        _verifyContract("Launcher", addresses.launcher);

        PonderToken(addresses.ponder).setLauncher(addresses.launcher);
        console.log("PONDER launcher set to:", addresses.launcher);

        addresses.masterChef = address(new PonderMasterChef(
            PonderToken(addresses.ponder),
            PonderFactory(addresses.factory),
            treasury,
            PONDER_PER_SECOND,
            block.timestamp
        ));
        _verifyContract("MasterChef", addresses.masterChef);

        return addresses;
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address teamReserve = vm.envAddress("TEAM_RESERVE_ADDRESS");
        address marketing = vm.envAddress("MARKETING_ADDRESS");
        address deployer = vm.addr(deployerPrivateKey);

        validateAddresses(treasury, teamReserve, marketing, deployer);

        vm.startBroadcast(deployerPrivateKey);

        DeploymentAddresses memory addresses = deployContracts(
            deployer,
            treasury,
            teamReserve,
            marketing
        );

        PonderToken(addresses.ponder).setMinter(addresses.masterChef);
        PonderFactory(addresses.factory).setLauncher(addresses.launcher);

        setupInitialPrices(
            PonderToken(addresses.ponder),
            addresses.router,
            PonderPriceOracle(addresses.oracle),
            addresses.ponderKubPair
        );

        vm.stopBroadcast();

        logDeployment(addresses, treasury);
    }

    function setupInitialPrices(
        PonderToken ponder,
        address router,
        PonderPriceOracle oracle,
        address ponderKubPair
    ) internal {
        console.log("Initial timestamp:", block.timestamp);

        ponder.approve(router, INITIAL_PONDER_AMOUNT);
        PonderRouter(payable(router)).addLiquidityETH{value: INITIAL_KUB_AMOUNT}(
            address(ponder),
            INITIAL_PONDER_AMOUNT,
            INITIAL_PONDER_AMOUNT,
            INITIAL_KUB_AMOUNT,
            address(this),
            block.timestamp + 1 hours
        );

        oracle.update(ponderKubPair);
    }

    function _verifyContract(string memory name, address contractAddress) internal view {
        uint256 size;
        assembly {
            size := extcodesize(contractAddress)
        }
        if (size == 0) revert DeploymentFailed(name);
        console.log(name, "deployed at:", contractAddress);
    }

    function logDeployment(DeploymentAddresses memory addresses, address treasury) internal view {
        console.log("\nDeployment Summary on Bitkub Chain:");
        console.log("--------------------------------");
        console.log("KKUB Address:", KKUB);
        console.log("PonderToken:", addresses.ponder);
        console.log("Factory:", addresses.factory);
        console.log("KKUBUnwrapper:", addresses.kkubUnwrapper);
        console.log("Router:", addresses.router);
        console.log("PriceOracle:", addresses.oracle);
        console.log("PONDER/KKUB Pair:", addresses.ponderKubPair);
        console.log("MasterChef:", addresses.masterChef);
        console.log("FiveFiveFiveLauncher:", addresses.launcher);
        console.log("Staking:", addresses.staking);
        console.log("Treasury:", treasury);

        console.log("\nInitial Liquidity Details:");
        console.log("--------------------------------");
        console.log("Initial KUB:", INITIAL_KUB_AMOUNT / 1e18);
        console.log("Initial PONDER:", INITIAL_PONDER_AMOUNT / 1e18);
        console.log("Initial PONDER Price in KUB:", INITIAL_KUB_AMOUNT * 1e18 / INITIAL_PONDER_AMOUNT);

        console.log("\nToken Allocation Summary:");
        console.log("--------------------------------");
        console.log("Liquidity Mining (40%):", uint256(400_000_000 * 1e18));
        console.log("Team/Reserve (15%):", uint256(150_000_000 * 1e18));
        console.log("Marketing/Community (10%):", uint256(100_000_000 * 1e18));
        console.log("Treasury/DAO (25%):", uint256(250_000_000 * 1e18));
    }

    receive() external payable {}
}

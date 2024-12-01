// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../src/core/PonderFactory.sol";
import "../../src/core/PonderMasterChef.sol";
import "../../src/core/PonderPriceOracle.sol";
import "../../src/core/PonderToken.sol";
import "../../src/launch/FiveFiveFiveLauncher.sol";
import "../../src/periphery/KKUBUnwrapper.sol";
import "../../src/periphery/PonderRouter.sol";
import "forge-std/Script.sol";

contract DeployBitkubScript is Script {
    // Total farming allocation is 400M PONDER over 4 years
    // This equals approximately 3.168 PONDER per second (400M / (4 * 365 * 24 * 60 * 60))
    uint256 constant PONDER_PER_SECOND = 3168000000000000000; // 3.168 ether
    address constant KKUB = 0x1de8A5c87d421f53eE4ae398cc766e62E88e9518;
    // testnet - 0x1de8A5c87d421f53eE4ae398cc766e62E88e9518
    // mainner - 0x67eBD850304c70d983B2d1b93ea79c7CD6c3F6b5

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address teamReserve = vm.envAddress("TEAM_RESERVE_ADDRESS");
        address marketing = vm.envAddress("MARKETING_ADDRESS");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy token first
        PonderToken ponder = new PonderToken(
            treasury,
            teamReserve,
            marketing
        );
        _verifyContract("PonderToken", address(ponder));

        // Deploy factory with temporary launcher address
        PonderFactory factory = new PonderFactory(deployer, address(1));
        _verifyContract("PonderFactory", address(factory));

        // Deploy KKUBUnwrapper
        KKUBUnwrapper kkubUnwrapper = new KKUBUnwrapper(KKUB);
        _verifyContract("KKUBUnwrapper", address(kkubUnwrapper));

        // Deploy router
        PonderRouter router = new PonderRouter(
            address(factory),
            KKUB,
            address(kkubUnwrapper)
        );
        _verifyContract("PonderRouter", address(router));

        // Deploy price oracle
        PonderPriceOracle oracle = new PonderPriceOracle(address(factory));
        _verifyContract("PonderPriceOracle", address(oracle));

        // Deploy MasterChef
        PonderMasterChef masterChef = new PonderMasterChef(
            ponder,
            factory,
            treasury,
            PONDER_PER_SECOND,
            block.timestamp
        );
        _verifyContract("MasterChef", address(masterChef));

        ponder.setMinter(address(masterChef));

        // Deploy FiveFiveFiveLauncher
        FiveFiveFiveLauncher launcher = new FiveFiveFiveLauncher(
            address(factory),
            payable(address(router)),
            treasury // Using same treasury address for fee collection
        );
        _verifyContract("FiveFiveFiveLauncher", address(launcher));

        // Update factory with correct launcher address
        factory.setLauncher(address(launcher));

        vm.stopBroadcast();

        console.log("\nDeployment Summary on Bitkub Chain:");
        console.log("--------------------------------");
        console.log("Deployer Address:", deployer);
        console.log("KKUB Address:", KKUB);
        console.log("PonderToken:", address(ponder));
        console.log("Factory:", address(factory));
        console.log("KKUBUnwrapper:", address(kkubUnwrapper));
        console.log("Router:", address(router));
        console.log("PriceOracle:", address(oracle));
        console.log("MasterChef:", address(masterChef));
        console.log("FiveFiveFiveLauncher:", address(launcher));

        // Additional deployment verification information
        console.log("\nVerification Info:");
        console.log("--------------------------------");
        console.log("Treasury/Fee Collector:", treasury);
        console.log("PONDER per second:", PONDER_PER_SECOND);
        console.log("Min to Launch:", 165 ether, "KUB");
        console.log("Min Contribution:", 0.55 ether, "KUB");
        console.log("LP Lock Period:", 180 days, "seconds");

        console.log("\nToken Allocation Summary:");
        console.log("--------------------------------");
        console.log("Initial Liquidity (10%):", uint256(100_000_000 * 1e18));
        console.log("Liquidity Mining (40%):", uint256(400_000_000 * 1e18));
        console.log("Team/Reserve (15%):", uint256(150_000_000 * 1e18));
        console.log("Marketing/Community (10%):", uint256(100_000_000 * 1e18));
        console.log("Treasury/DAO (25%):", uint256(250_000_000 * 1e18));
    }

    function _verifyContract(string memory name, address contractAddress) internal view {
        uint256 size;
        assembly {
            size := extcodesize(contractAddress)
        }
        require(size > 0, string(abi.encodePacked(name, " deployment failed")));
        console.log(name, "deployed at:", contractAddress);
    }
}

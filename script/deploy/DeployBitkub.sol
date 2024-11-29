// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../../src/core/PonderToken.sol";
import "../../src/core/PonderFactory.sol";
import "../../src/periphery/PonderRouter.sol";
import "../../src/periphery/KKUBUnwrapper.sol";
import "../../src/core/PonderMasterChef.sol";
import "../../src/launch/FiveFiveFiveLauncher.sol";

contract DeployBitkubScript is Script {
    uint256 constant PONDER_PER_SECOND = 0.1e18;
    address constant KKUB = 0x1de8A5c87d421f53eE4ae398cc766e62E88e9518;
    // testnet - 0x1de8A5c87d421f53eE4ae398cc766e62E88e9518
    // mainner - 0x67eBD850304c70d983B2d1b93ea79c7CD6c3F6b5

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        PonderToken ponder = new PonderToken();
        _verifyContract("PonderToken", address(ponder));

        PonderFactory factory = new PonderFactory(deployer);
        _verifyContract("PonderFactory", address(factory));

        // Deploy KKUBUnwrapper first
        KKUBUnwrapper kkubUnwrapper = new KKUBUnwrapper(KKUB);
        _verifyContract("KKUBUnwrapper", address(kkubUnwrapper));

        PonderRouter router = new PonderRouter(
            address(factory),
            KKUB,
            address(kkubUnwrapper)
        );
        _verifyContract("PonderRouter", address(router));

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

        vm.stopBroadcast();

        console.log("\nDeployment Summary on Bitkub Chain:");
        console.log("--------------------------------");
        console.log("Deployer Address:", deployer);
        console.log("KKUB Address:", KKUB);
        console.log("PonderToken:", address(ponder));
        console.log("Factory:", address(factory));
        console.log("KKUBUnwrapper:", address(kkubUnwrapper));
        console.log("Router:", address(router));
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

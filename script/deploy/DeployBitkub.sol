// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../../src/core/PonderToken.sol";
import "../../src/core/PonderFactory.sol";
import "../../src/periphery/PonderRouter.sol";
import "../../src/periphery/KKUBUnwrapper.sol";
import "../../src/core/PonderMasterChef.sol";

contract DeployBitkubScript is Script {
    uint256 constant PONDER_PER_SECOND = 0.1e18;
    address constant KKUB = 0x67eBD850304c70d983B2d1b93ea79c7CD6c3F6b5;

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

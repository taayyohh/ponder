// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../../src/core/PonderToken.sol";
import "../../src/core/PonderFactory.sol";
import "../../src/periphery/PonderRouter.sol";
import "../../src/core/PonderMasterChef.sol";
import "../../src/core/PonderSafeguard.sol";
import "../../src/interfaces/IPonderRouter.sol";

contract DeployBitkubScript is Script {
    // Configuration
    uint256 constant PONDER_PER_SECOND = 0.1e18; // 0.1 PONDER per second

    // WKUB on Bitkub Chain (with correct checksum)
    address constant WKUB = 0xF28cAc2532d77826C725C6092A15E98a50c79FD0;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address treasury = vm.envAddress("TREASURY_ADDRESS");

        // Get deployer address
        address deployer = vm.addr(deployerPrivateKey);

        // Pre-deployment checks
        _verifyPreDeployment();

        vm.startBroadcast(deployerPrivateKey);

        // Deploy core contracts
        PonderToken ponder = new PonderToken();
        _verifyContract("PonderToken", address(ponder));

        // Use deployer address explicitly for factory owner
        PonderFactory factory = new PonderFactory(deployer);
        _verifyContract("PonderFactory", address(factory));

        PonderSafeguard safeguard = new PonderSafeguard();
        _verifyContract("PonderSafeguard", address(safeguard));

        PonderRouter router = new PonderRouter(
            address(factory),
            WKUB
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

        // Setup permissions
        ponder.setMinter(address(masterChef));
        factory.setSafeguard(address(safeguard));

        // Post-deployment verification
        _verifyPostDeployment(
            address(ponder),
            address(factory),
            address(router),
            address(masterChef),
            address(safeguard)
        );

        vm.stopBroadcast();

        // Log deployment summary
        console.log("\nDeployment Summary on Bitkub Chain:");
        console.log("--------------------------------");
        console.log("Deployer Address:", deployer);
        console.log("WKUB Address:", WKUB);
        console.log("PonderToken:", address(ponder));
        console.log("Factory:", address(factory));
        console.log("Router:", address(router));
        console.log("MasterChef:", address(masterChef));
        console.log("Safeguard:", address(safeguard));
    }

    function _verifyPreDeployment() internal view {
        // Verify WKUB exists
        uint256 size;
        address wkub = WKUB;
        assembly {
            size := extcodesize(wkub)
        }
        require(size > 0, "WKUB contract not found at specified address");
    }

    function _verifyContract(string memory name, address contractAddress) internal view {
        uint256 size;
        assembly {
            size := extcodesize(contractAddress)
        }
        require(size > 0, string(abi.encodePacked(name, " deployment failed")));
        console.log(name, "deployed at:", contractAddress);
    }

    function _verifyPostDeployment(
        address ponderToken,
        address factoryAddress,
        address routerAddress,
        address masterChefAddress,
        address safeguardAddress
    ) internal view {
        // Verify PonderToken configuration
        PonderToken ponder = PonderToken(ponderToken);
        require(ponder.minter() == masterChefAddress, "MasterChef not set as minter");

        // Verify Factory configuration
        PonderFactory factory = PonderFactory(factoryAddress);
        require(factory.safeguard() == safeguardAddress, "Safeguard not set in factory");

        // Verify Router factory and WKUB
        IPonderRouter router = IPonderRouter(routerAddress);
        require(address(router.factory()) == factoryAddress, "Router factory mismatch");
        require(router.WETH() == WKUB, "Router WKUB mismatch");

        // Verify MasterChef configuration
        PonderMasterChef masterChef = PonderMasterChef(masterChefAddress);
        require(address(masterChef.ponder()) == ponderToken, "MasterChef ponder mismatch");
        require(address(masterChef.factory()) == factoryAddress, "MasterChef factory mismatch");

        console.log("\nAll post-deployment verifications passed!");
    }
}

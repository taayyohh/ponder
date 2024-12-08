// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../../test/mocks/KKUB.sol";
import "../../test/mocks/MockKYC.sol";

contract DeployKKUBWithMockKYC is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy Mock KYC contract
        MockKYC mockKYC = new MockKYC();
        console.log("MockKYC deployed at:", address(mockKYC));

        // Deploy KKUB with the Mock KYC contract
        KKUB kkub = new KKUB(deployer, address(mockKYC));
        console.log("KKUB deployed at:", address(kkub));

        // Mint 100,000 KKUB to the deployer's address
        uint256 amountToMint = 10 ether;
        kkub.deposit{value: amountToMint}();
        console.log("Minted 10 KKUB to:", deployer);

        vm.stopBroadcast();
    }
}

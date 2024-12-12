// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../../test/mocks/ERC20.sol";

contract DeployMockUSDTScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the ERC20 contract as a mock USDT with name "Test USDT" and symbol "tUSDT"
        ERC20 mockUSDT = new ERC20("Test USDT", "tUSDT", 18);

        // Mint 1,000,000 tUSDT to the deployer address
        mockUSDT.mint(msg.sender, 1_000_000 * 10 ** 18);

        console.log("Mock USDT deployed to:", address(mockUSDT));

        vm.stopBroadcast();
    }
}

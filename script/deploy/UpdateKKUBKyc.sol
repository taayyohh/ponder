// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../../test/mocks/MockKYC.sol";

contract SetKKUBUnwrapperKYC is Script {
    function run() external {
        vm.startBroadcast();

        // Replace with the deployed Mock KYC and KKUBUnwrapper addresses
        address mockKYCAddress = vm.envAddress("MOCK_KYC_ADDRESS");
        address kkubUnwrapperAddress = vm.envAddress("KKUB_UNWRAPPER_ADDRESS");

        MockKYC mockKYC = MockKYC(mockKYCAddress);
        mockKYC.setKYCLevel(kkubUnwrapperAddress, 2);  // Set a compliant KYC level (e.g., 2)

        console.log("KKUBUnwrapper set as a compliant KYC address");

        vm.stopBroadcast();
    }
}

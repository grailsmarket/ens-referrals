//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import {Script, console} from "forge-std/Script.sol";
import {BulkRenewalWithReferral} from "../src/BulkRenewalWithReferral.sol";

contract BulkRenewScript is Script {
    // Deployed BulkRenewalWithReferral contract address
    // Update this after deployment or pass via environment variable
    address constant MAINNET_RENEWAL_CONTRACT = address(0xafC5a354A159dC900bb9Ea1082d3E20a3Cd65026); // TODO: Set after deployment
    address constant SEPOLIA_RENEWAL_CONTRACT = address(0); // TODO: Set after deployment

    function run() public {
        // Configure renewal parameters
        string[] memory labels = new string[](3);
        uint256[] memory durations = new uint256[](3);

        labels[0] = "hyperstate";
        labels[1] = "jackflash";
        labels[2] = "0xthrpw";
        durations[0] =  31 days; // 1 year renewal
        durations[1] =  31 days; // 1 year renewal
        durations[2] =  31 days; // 1 year renewal

        // Get the renewal contract address for current network
        address renewalContractAddr = getRenewalContractAddress();
        require(renewalContractAddr != address(0), "Renewal contract address not set for this network");

        BulkRenewalWithReferral renewalContract = BulkRenewalWithReferral(
            payable(renewalContractAddr)
        );

        // Calculate the total price
        uint256 totalPrice = renewalContract.bulkRentPrice(labels, durations);

        console.log("=== Bulk Renewal Script ===");
        console.log("Network Chain ID:", block.chainid);
        console.log("Renewal Contract:", renewalContractAddr);
        console.log("");
        console.log("Names to renew:");
        for (uint256 i = 0; i < labels.length; i++) {
            console.log("  - %s for %d days", labels[i], durations[i] / 1 days);
        }
        console.log("");
        console.log("Total price (wei):", totalPrice);

        // Start broadcasting transactions
        vm.startBroadcast();

        // Execute bulk renewal
        renewalContract.bulkRenew{value: totalPrice}(labels, durations);

        vm.stopBroadcast();

        console.log("");
        console.log("Bulk renewal completed successfully!");
    }

    function getRenewalContractAddress() internal view returns (address) {
        uint256 chainId = block.chainid;

        if (chainId == 1) {
            return MAINNET_RENEWAL_CONTRACT;
        } else if (chainId == 11155111) {
            return SEPOLIA_RENEWAL_CONTRACT;
        } else {
            revert("Unsupported network");
        }
    }
}

/// @notice Alternative script that accepts parameters via environment variables
/// Usage:
///   RENEWAL_CONTRACT=0x... LABEL=hyperstate DURATION_DAYS=365 REFERRER=0x... \
///   forge script script/BulkRenew.s.sol:BulkRenewEnvScript --rpc-url mainnet --broadcast
contract BulkRenewEnvScript is Script {
    function run() public {
        // Read configuration from environment variables
        address renewalContractAddr = vm.envAddress("RENEWAL_CONTRACT");
        string memory label = vm.envString("LABEL");
        uint256 durationDays = vm.envUint("DURATION_DAYS");

        // Build arrays
        string[] memory labels = new string[](1);
        labels[0] = label;

        uint256[] memory durations = new uint256[](1);
        durations[0] = durationDays * 1 days;

        BulkRenewalWithReferral renewalContract = BulkRenewalWithReferral(
            payable(renewalContractAddr)
        );

        // Calculate the total price
        uint256 totalPrice = renewalContract.bulkRentPrice(labels, durations);

        console.log("=== Bulk Renewal Script (Env Config) ===");
        console.log("Renewal Contract:", renewalContractAddr);
        console.log("Label:", labels[0]);
        console.log("Duration (days):", durations[0] / 1 days);
        console.log("Total price (wei):", totalPrice);

        vm.startBroadcast();
        renewalContract.bulkRenew{value: totalPrice}(labels, durations);
        vm.stopBroadcast();

        console.log("Bulk renewal completed!");
    }
}

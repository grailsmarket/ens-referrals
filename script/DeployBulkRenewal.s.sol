//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import {Script, console} from "forge-std/Script.sol";
import {ENS} from "ens-contracts/registry/ENS.sol";
import {IWrappedEthRegistrarController} from "../src/IWrappedEthRegistrarController.sol";
import {IRegistrarRenewalWithReferral} from "../src/IRegistrarRenewalWithReferral.sol";
import {BulkRenewalWithReferral} from "../src/BulkRenewalWithReferral.sol";

contract DeployScript is Script {
    function run() public {
        // Determine network and addresses
        (ENS ens, IWrappedEthRegistrarController wrappedController, IRegistrarRenewalWithReferral renewalWithReferral) = getNetworkAddresses();
        bytes32 referrer = 0x0000000000000000000000007e491cde0fbf08e51f54c4fb6b9e24afbd18966d;

        console.log("Deploying BulkRenewalWithReferral...");
        console.log("ENS Registry:", address(ens));
        console.log("Wrapped Controller:", address(wrappedController));
        console.log("Renewal With Referral:", address(renewalWithReferral));

        // Start broadcasting transactions
        vm.startBroadcast();

        // Deploy the contract
        BulkRenewalWithReferral renewal = new BulkRenewalWithReferral(ens, wrappedController, renewalWithReferral, referrer);

        vm.stopBroadcast();

        console.log("BulkRenewalWithReferral deployed at:", address(renewal));
    }

    function getNetworkAddresses() internal view returns (ENS ens, IWrappedEthRegistrarController wrappedController, IRegistrarRenewalWithReferral renewalWithReferral) {
        uint256 chainId = block.chainid;

        if (chainId == 1) {
            // Mainnet
            ens = ENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
            wrappedController = IWrappedEthRegistrarController(0x253553366Da8546fC250F225fe3d25d0C782303b);
            renewalWithReferral = IRegistrarRenewalWithReferral(0xf55575Bde5953ee4272d5CE7cdD924c74d8fA81A);
        } else if (chainId == 11155111) {
            // Sepolia testnet
            ens = ENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
            wrappedController = IWrappedEthRegistrarController(0xFED6a969AaA60E4961FCD3EBF1A2e8913ac65B72);
            renewalWithReferral = IRegistrarRenewalWithReferral(0x7AB2947592C280542e680Ba8f08A589009da8644);
        } else {
            revert("Unsupported network");
        }
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import {ENS} from "ens-contracts/registry/ENS.sol";
import {ReverseClaimer} from "ens-contracts/reverseRegistrar/ReverseClaimer.sol";
import {IPriceOracle} from "ens-contracts/ethregistrar/IPriceOracle.sol";
import {IWrappedEthRegistrarController} from "./IWrappedEthRegistrarController.sol";
import {IBulkRenewalWithReferral} from "./IBulkRenewalWithReferral.sol";
import {IRegistrarRenewalWithReferral} from "./IRegistrarRenewalWithReferral.sol";

/**
 * @title BulkRenewalWithReferrer
 * @notice A contract for renewing multiple ENS names via the 
 * IRegistrarRenewalWithReferral with referral tracking.
 *
 * This contract provides a bulk renewal function that:
 * 1. Accepts an array of names, an array of durations and a referrer,
 * 2. Uses IWrappedEthRegistrarController to get pricing information, and
 * 3. Calls REGISTRAR_RENEWAL_WITH_REFERRAL.renew() for each name and duration,
 * 4. Refunds the sender any overpayment.
 *
 */
contract BulkRenewalWithReferral is IBulkRenewalWithReferral, ReverseClaimer {
    IWrappedEthRegistrarController immutable WRAPPED_ETH_REGISTRAR_CONTROLLER;
    IRegistrarRenewalWithReferral immutable REGISTRAR_RENEWAL_WITH_REFERRAL;
    bytes32 immutable REFERRER;

    constructor(
        ENS ens, 
        IWrappedEthRegistrarController _wrappedEthRegistrarController,
        IRegistrarRenewalWithReferral _bulkRenewalWithReferral,
        bytes32 _referrer
    ) ReverseClaimer(ens, msg.sender) {
        WRAPPED_ETH_REGISTRAR_CONTROLLER = _wrappedEthRegistrarController;
        REGISTRAR_RENEWAL_WITH_REFERRAL = _bulkRenewalWithReferral;
        REFERRER = _referrer;
    }

    /**
     * @notice Calculates the total cost to renew multiple ENS names
     * @param labels Array of .eth subname labels to renew
     * @param durations Array of durations corresponding to each label
     * @return total The total cost in wei to renew all names
     */
    function bulkRentPrice(
        string[] calldata labels,
        uint256[] calldata durations
    ) external view returns (uint256 total) {
        uint256 length = labels.length;
        require(length == durations.length, "Array length mismatch");

        for (uint256 i = 0; i < length;) {
            IPriceOracle.Price memory price = WRAPPED_ETH_REGISTRAR_CONTROLLER.rentPrice(labels[i], durations[i]);
            unchecked {
                ++i;
                total += (price.base + price.premium);
            }
        }
    }

    /**
     * @notice Renews multiple ENS names with referral tracking in a single transaction
     * @param labels Array of .eth subname labels to renew
     * @param durations Array of durations corresponding to each label
     */
    function bulkRenew(
        string[] calldata labels,
        uint256[] calldata durations
    ) external payable {
        uint256 length = labels.length;
        require(length == durations.length, "Array length mismatch");

        for (uint256 i = 0; i < length;) {
            // Get price for this specific renewal
            IPriceOracle.Price memory price = WRAPPED_ETH_REGISTRAR_CONTROLLER.rentPrice(labels[i], durations[i]);
            uint256 cost = price.base + price.premium;

            // Renew with exact cost
            REGISTRAR_RENEWAL_WITH_REFERRAL.renew{value: cost}(labels[i], durations[i], REFERRER);

            unchecked {
                ++i;
            }
        }

        // Refund any excess ETH
        if (address(this).balance > 0) {
            (bool success,) = msg.sender.call{value: address(this).balance}("");
            require(success, "ETH transfer failed");
        }
    }

    receive() external payable {}
}

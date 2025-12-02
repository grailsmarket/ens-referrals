//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import {ENS} from "ens-contracts/registry/ENS.sol";
import {ReverseClaimer} from "ens-contracts/reverseRegistrar/ReverseClaimer.sol";
import {IPriceOracle} from "ens-contracts/ethregistrar/IPriceOracle.sol";
import {IWrappedEthRegistrarController} from "./IWrappedEthRegistrarController.sol";
import {IRegistrarRenewalWithReferral} from "./IRegistrarRenewalWithReferral.sol";

/**
 * @title UniversalRegistrarRenewalWithReferrer
 * @notice A contract for renewing ENS names via the WrappedEthRegistrarController with referral tracking.
 *
 * This contract provides a simplified renewal process that:
 * 1. Calls WRAPPED_ETH_REGISTRAR_CONTROLLER.renew(),
 * 2. Emits the RenewalReferred event for referral tracking, and
 * 3. Refunds the sender any overpayment.
 *
 * To use, replace UnwrappedEthRegistrarController.renew() with UniversalRegistrarRenewalWithReferrer.renew()
 * and all renewal transactions will include the referrer event.
 */
contract UniversalRegistrarRenewalWithReferrer is IRegistrarRenewalWithReferral, ReverseClaimer {
    IWrappedEthRegistrarController immutable WRAPPED_ETH_REGISTRAR_CONTROLLER;

    /// @notice Emitted when a name is renewed with a referrer.
    ///
    /// @param label The .eth subname label
    /// @param labelHash The keccak256 hash of the .eth subname label
    /// @param cost The actual cost of the renewal
    /// @param duration The duration of the renewal
    /// @param referrer The referrer of the renewal
    event RenewalReferred(string label, bytes32 indexed labelHash, uint256 cost, uint256 duration, bytes32 referrer);

    constructor(ENS ens, IWrappedEthRegistrarController _wrappedEthRegistrarController) ReverseClaimer(ens, msg.sender) {
        WRAPPED_ETH_REGISTRAR_CONTROLLER = _wrappedEthRegistrarController;
    }

    /**
     * @notice Renews an ENS name with referral tracking
     * @param label The label of the .eth subname to renew
     * @param duration The duration to extend the registration
     * @param referrer The referrer of the renewal
     * @dev Gas usage: ~117k
     */
    function renew(string calldata label, uint256 duration, bytes32 referrer) external payable {
        // 1. Call WRAPPED_ETH_REGISTRAR_CONTROLLER.renew() & infer cost
        uint256 prevBalance = address(this).balance;
        WRAPPED_ETH_REGISTRAR_CONTROLLER.renew{value: msg.value}(label, duration);
        uint256 currBalance = address(this).balance;
        uint256 cost = prevBalance - currBalance;

        // 2. Emit the RenewalReferred event with actual cost spent and indexed labelHash for searchability
        // NOTE: we emit `duration` instead of `expiry` to avoid the gas cost of reading the new
        // expiry from the Registry
        emit RenewalReferred(label, keccak256(bytes(label)), cost, duration, referrer);

        // 3. Refund sender contract balance
        if (currBalance > 0) {
            (bool success,) = msg.sender.call{value: currBalance}("");
            require(success, "ETH transfer failed");
        }
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
     * @param referrer The referrer for all renewals
     */
    function bulkRenew(
        string[] calldata labels,
        uint256[] calldata durations,
        bytes32 referrer
    ) external payable {
        uint256 length = labels.length;
        require(length == durations.length, "Array length mismatch");

        for (uint256 i = 0; i < length;) {
            // Get price for this specific renewal
            IPriceOracle.Price memory price = WRAPPED_ETH_REGISTRAR_CONTROLLER.rentPrice(labels[i], durations[i]);
            uint256 cost = price.base + price.premium;

            // Renew with exact cost
            WRAPPED_ETH_REGISTRAR_CONTROLLER.renew{value: cost}(labels[i], durations[i]);

            // Emit referral event for each renewal
            emit RenewalReferred(labels[i], keccak256(bytes(labels[i])), cost, durations[i], referrer);

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

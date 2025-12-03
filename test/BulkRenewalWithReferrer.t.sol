//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {ENS} from "ens-contracts/registry/ENS.sol";
import {INameWrapper} from "ens-contracts/wrapper/INameWrapper.sol";
import {IBaseRegistrar} from "ens-contracts/ethregistrar/IBaseRegistrar.sol";
import {IPriceOracle} from "ens-contracts/ethregistrar/IPriceOracle.sol";
import {NameCoder} from "ens-contracts/utils/NameCoder.sol";

import {IWrappedEthRegistrarController} from "../src/IWrappedEthRegistrarController.sol";
import {IRegistrarRenewalWithReferral} from "../src/IRegistrarRenewalWithReferral.sol";
import {BulkRenewalWithReferral} from "../src/BulkRenewalWithReferral.sol";

contract ReferralsTest is Test {
    ENS constant ENS_REGISTRY = ENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
    INameWrapper constant NAME_WRAPPER = INameWrapper(0xD4416b13d2b3a9aBae7AcD5D6C2BbDBE25686401);
    IWrappedEthRegistrarController constant WRAPPED_ETH_REGISTRAR_CONTROLLER =
        IWrappedEthRegistrarController(0x253553366Da8546fC250F225fe3d25d0C782303b);
    IBaseRegistrar constant BASE_REGISTRAR = IBaseRegistrar(0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85);
    IRegistrarRenewalWithReferral constant REGISTRAR_RENEWAL_WITH_REFERRAL =
        IRegistrarRenewalWithReferral(0xf55575Bde5953ee4272d5CE7cdD924c74d8fA81A);

    string constant TEST_LEGACY_LABEL = "shrugs"; // registered via LegacyEthRegistrarController
    string constant TEST_WRAPPED_LABEL = "cowfish"; // registered via WrappedEthRegistrarController
    string constant TEST_UNWRAPPED_LABEL = "daonotes"; // registered via UnwrappedEthRegistrarController

    uint256 constant TEST_DURATION = 365 days;

    // forge-lint: disable-next-line(mixed-case-variable)
    bytes32 REFERRER = keccak256("test-referrer"); // TODO: referrer formatting

    address renewer = vm.addr(1239586324895);
    BulkRenewalWithReferral renewalContract;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));

        renewalContract = new BulkRenewalWithReferral(
            ENS_REGISTRY, 
            WRAPPED_ETH_REGISTRAR_CONTROLLER, 
            REGISTRAR_RENEWAL_WITH_REFERRAL, 
            REFERRER
        );

        // set renewalContract's balance to 0 because this address on mainnet has a balance
        vm.deal(address(renewalContract), 0);
        assertEq(address(renewalContract).balance, 0, "Must start with 0 excess balance");

        vm.deal(renewer, 10 ether);
        assertEq(renewer.balance, 10 ether, "Must start with dealt balance");

        vm.startPrank(renewer);
    }

    // ============ Bulk Renewal Tests ============

    // ---------- bulkRentPrice Tests ----------

    function test_bulkRentPrice_singleName() public view {
        string[] memory labels = new string[](1);
        uint256[] memory durations = new uint256[](1);
        labels[0] = TEST_WRAPPED_LABEL;
        durations[0] = TEST_DURATION;

        // Get expected price from controller directly
        IPriceOracle.Price memory expectedPrice = WRAPPED_ETH_REGISTRAR_CONTROLLER.rentPrice(TEST_WRAPPED_LABEL, TEST_DURATION);
        uint256 expectedTotal = expectedPrice.base + expectedPrice.premium;

        // Get bulk price
        uint256 totalPrice = renewalContract.bulkRentPrice(labels, durations);

        assertEq(totalPrice, expectedTotal, "Single name bulk price should match controller price");
    }

    function test_bulkRentPrice_multipleNames() public view {
        string[] memory labels = new string[](3);
        uint256[] memory durations = new uint256[](3);
        labels[0] = TEST_WRAPPED_LABEL;
        labels[1] = TEST_UNWRAPPED_LABEL;
        labels[2] = TEST_LEGACY_LABEL;
        durations[0] = TEST_DURATION;
        durations[1] = TEST_DURATION;
        durations[2] = TEST_DURATION;

        // Calculate expected total from controller
        uint256 expectedTotal = 0;
        for (uint256 i = 0; i < labels.length; i++) {
            IPriceOracle.Price memory price = WRAPPED_ETH_REGISTRAR_CONTROLLER.rentPrice(labels[i], durations[i]);
            expectedTotal += price.base + price.premium;
        }

        // Get bulk price
        uint256 totalPrice = renewalContract.bulkRentPrice(labels, durations);

        assertEq(totalPrice, expectedTotal, "Multiple names bulk price should match sum of individual prices");
    }

    function test_bulkRentPrice_differentDurations() public view {
        string[] memory labels = new string[](3);
        uint256[] memory durations = new uint256[](3);
        labels[0] = TEST_WRAPPED_LABEL;
        labels[1] = TEST_UNWRAPPED_LABEL;
        labels[2] = TEST_LEGACY_LABEL;
        durations[0] = 365 days; // 1 year
        durations[1] = 730 days; // 2 years
        durations[2] = 1095 days; // 3 years

        // Calculate expected total from controller
        uint256 expectedTotal = 0;
        for (uint256 i = 0; i < labels.length; i++) {
            IPriceOracle.Price memory price = WRAPPED_ETH_REGISTRAR_CONTROLLER.rentPrice(labels[i], durations[i]);
            expectedTotal += price.base + price.premium;
        }

        // Get bulk price
        uint256 totalPrice = renewalContract.bulkRentPrice(labels, durations);

        assertEq(totalPrice, expectedTotal, "Bulk price with different durations should be correct");
    }

    function test_bulkRentPrice_emptyArrays() public view {
        string[] memory labels = new string[](0);
        uint256[] memory durations = new uint256[](0);

        uint256 totalPrice = renewalContract.bulkRentPrice(labels, durations);

        assertEq(totalPrice, 0, "Empty arrays should return zero price");
    }

    function test_bulkRentPrice_revertsOnArrayLengthMismatch() public {
        string[] memory labels = new string[](2);
        uint256[] memory durations = new uint256[](3);
        labels[0] = TEST_WRAPPED_LABEL;
        labels[1] = TEST_UNWRAPPED_LABEL;
        durations[0] = TEST_DURATION;
        durations[1] = TEST_DURATION;
        durations[2] = TEST_DURATION;

        vm.expectRevert("Array length mismatch");
        renewalContract.bulkRentPrice(labels, durations);
    }

    function test_bulkRentPrice_revertsOnArrayLengthMismatch_labelsLonger() public {
        string[] memory labels = new string[](3);
        uint256[] memory durations = new uint256[](2);
        labels[0] = TEST_WRAPPED_LABEL;
        labels[1] = TEST_UNWRAPPED_LABEL;
        labels[2] = TEST_LEGACY_LABEL;
        durations[0] = TEST_DURATION;
        durations[1] = TEST_DURATION;

        vm.expectRevert("Array length mismatch");
        renewalContract.bulkRentPrice(labels, durations);
    }

    // ---------- bulkRenew Tests ----------

    function test_bulkRenew_singleName() public {
        string[] memory labels = new string[](1);
        uint256[] memory durations = new uint256[](1);
        labels[0] = TEST_WRAPPED_LABEL;
        durations[0] = TEST_DURATION;

        bytes32 labelHash = keccak256(bytes(TEST_WRAPPED_LABEL));
        uint256 labelTokenId = uint256(labelHash);

        // Get initial expiry
        uint256 initialExpiry = BASE_REGISTRAR.nameExpires(labelTokenId);

        // Calculate price
        uint256 totalPrice = renewalContract.bulkRentPrice(labels, durations);

        // Bulk renew
        renewalContract.bulkRenew{value: totalPrice}(labels, durations);

        // Assert expiry updated
        uint256 newExpiry = BASE_REGISTRAR.nameExpires(labelTokenId);
        assertEq(newExpiry, initialExpiry + TEST_DURATION, "Expiry should be updated after bulk renewal");
    }

    function test_bulkRenew_multipleNames() public {
        string[] memory labels = new string[](3);
        uint256[] memory durations = new uint256[](3);
        labels[0] = TEST_WRAPPED_LABEL;
        labels[1] = TEST_UNWRAPPED_LABEL;
        labels[2] = TEST_LEGACY_LABEL;
        durations[0] = TEST_DURATION;
        durations[1] = TEST_DURATION;
        durations[2] = TEST_DURATION;

        // Get initial expiries
        uint256[] memory initialExpiries = new uint256[](3);
        for (uint256 i = 0; i < labels.length; i++) {
            bytes32 labelHash = keccak256(bytes(labels[i]));
            initialExpiries[i] = BASE_REGISTRAR.nameExpires(uint256(labelHash));
        }

        // Calculate total price
        uint256 totalPrice = renewalContract.bulkRentPrice(labels, durations);

        // Bulk renew
        renewalContract.bulkRenew{value: totalPrice}(labels, durations);

        // Assert all expiries updated
        for (uint256 i = 0; i < labels.length; i++) {
            bytes32 labelHash = keccak256(bytes(labels[i]));
            uint256 newExpiry = BASE_REGISTRAR.nameExpires(uint256(labelHash));
            assertEq(newExpiry, initialExpiries[i] + durations[i], "Expiry should be updated for each name");
        }
    }

    function test_bulkRenew_differentDurations() public {
        string[] memory labels = new string[](3);
        uint256[] memory durations = new uint256[](3);
        labels[0] = TEST_WRAPPED_LABEL;
        labels[1] = TEST_UNWRAPPED_LABEL;
        labels[2] = TEST_LEGACY_LABEL;
        durations[0] = 365 days; // 1 year
        durations[1] = 730 days; // 2 years
        durations[2] = 1095 days; // 3 years

        // Get initial expiries
        uint256[] memory initialExpiries = new uint256[](3);
        for (uint256 i = 0; i < labels.length; i++) {
            bytes32 labelHash = keccak256(bytes(labels[i]));
            initialExpiries[i] = BASE_REGISTRAR.nameExpires(uint256(labelHash));
        }

        // Calculate total price
        uint256 totalPrice = renewalContract.bulkRentPrice(labels, durations);

        // Bulk renew
        renewalContract.bulkRenew{value: totalPrice}(labels, durations);

        // Assert each name has correct new expiry based on its specific duration
        for (uint256 i = 0; i < labels.length; i++) {
            bytes32 labelHash = keccak256(bytes(labels[i]));
            uint256 newExpiry = BASE_REGISTRAR.nameExpires(uint256(labelHash));
            assertEq(
                newExpiry,
                initialExpiries[i] + durations[i],
                string.concat("Expiry should be updated correctly for ", labels[i])
            );
        }
    }

    function test_bulkRenew_withOverpayment() public {
        string[] memory labels = new string[](2);
        uint256[] memory durations = new uint256[](2);
        labels[0] = TEST_WRAPPED_LABEL;
        labels[1] = TEST_UNWRAPPED_LABEL;
        durations[0] = TEST_DURATION;
        durations[1] = TEST_DURATION;

        // Calculate exact price
        uint256 totalPrice = renewalContract.bulkRentPrice(labels, durations);
        uint256 overpayment = 0.1 ether;

        uint256 renewerBalanceBefore = renewer.balance;

        // Bulk renew with overpayment
        renewalContract.bulkRenew{value: totalPrice + overpayment}(labels, durations);

        // Assert renewer received refund
        uint256 renewerBalanceAfter = renewer.balance;
        assertEq(
            renewerBalanceBefore - renewerBalanceAfter,
            totalPrice,
            "Renewer should only spend the exact renewal cost (overpayment refunded)"
        );

        // Assert contract has no remaining balance
        assertEq(address(renewalContract).balance, 0, "Contract should have no remaining balance");
    }

    function test_bulkRenew_exactPayment() public {
        string[] memory labels = new string[](2);
        uint256[] memory durations = new uint256[](2);
        labels[0] = TEST_WRAPPED_LABEL;
        labels[1] = TEST_UNWRAPPED_LABEL;
        durations[0] = TEST_DURATION;
        durations[1] = TEST_DURATION;

        // Calculate exact price
        uint256 totalPrice = renewalContract.bulkRentPrice(labels, durations);

        uint256 renewerBalanceBefore = renewer.balance;

        // Bulk renew with exact payment
        renewalContract.bulkRenew{value: totalPrice}(labels, durations);

        // Assert renewer spent exact amount
        uint256 renewerBalanceAfter = renewer.balance;
        assertEq(renewerBalanceBefore - renewerBalanceAfter, totalPrice, "Renewer should spend exact renewal cost");

        // Assert contract has no remaining balance
        assertEq(address(renewalContract).balance, 0, "Contract should have no remaining balance");
    }

    function test_bulkRenew_emptyArrays() public {
        string[] memory labels = new string[](0);
        uint256[] memory durations = new uint256[](0);

        uint256 renewerBalanceBefore = renewer.balance;
        uint256 sentValue = 0.1 ether;

        // Bulk renew with empty arrays should refund everything
        renewalContract.bulkRenew{value: sentValue}(labels, durations);

        // Assert full refund
        assertEq(renewer.balance, renewerBalanceBefore, "All ETH should be refunded for empty arrays");
        assertEq(address(renewalContract).balance, 0, "Contract should have no remaining balance");
    }

    function test_bulkRenew_withZeroReferrer() public {
        string[] memory labels = new string[](2);
        uint256[] memory durations = new uint256[](2);
        labels[0] = TEST_WRAPPED_LABEL;
        labels[1] = TEST_UNWRAPPED_LABEL;
        durations[0] = TEST_DURATION;
        durations[1] = TEST_DURATION;

        uint256 totalPrice = renewalContract.bulkRentPrice(labels, durations);

        // Bulk renew with zero referrer
        renewalContract.bulkRenew{value: totalPrice}(labels, durations);
    }

    function test_bulkRenew_revertsOnArrayLengthMismatch() public {
        string[] memory labels = new string[](2);
        uint256[] memory durations = new uint256[](3);
        labels[0] = TEST_WRAPPED_LABEL;
        labels[1] = TEST_UNWRAPPED_LABEL;
        durations[0] = TEST_DURATION;
        durations[1] = TEST_DURATION;
        durations[2] = TEST_DURATION;

        uint256 payment = 1 ether;

        vm.expectRevert("Array length mismatch");
        renewalContract.bulkRenew{value: payment}(labels, durations);
    }

    function test_bulkRenew_revertsOnInsufficientPayment() public {
        string[] memory labels = new string[](2);
        uint256[] memory durations = new uint256[](2);
        labels[0] = TEST_WRAPPED_LABEL;
        labels[1] = TEST_UNWRAPPED_LABEL;
        durations[0] = TEST_DURATION;
        durations[1] = TEST_DURATION;

        // Calculate exact price and send less
        uint256 totalPrice = renewalContract.bulkRentPrice(labels, durations);
        uint256 insufficientPayment = totalPrice / 2;

        vm.expectRevert();
        renewalContract.bulkRenew{value: insufficientPayment}(labels, durations);
    }

    function test_bulkRenew_withPreExistingContractBalance() public {
        // Send some ETH to the contract before renewal
        uint256 excessBalance = 0.05 ether;
        payable(address(renewalContract)).transfer(excessBalance);
        assertEq(address(renewalContract).balance, excessBalance, "Contract should have pre-existing balance");

        string[] memory labels = new string[](2);
        uint256[] memory durations = new uint256[](2);
        labels[0] = TEST_WRAPPED_LABEL;
        labels[1] = TEST_UNWRAPPED_LABEL;
        durations[0] = TEST_DURATION;
        durations[1] = TEST_DURATION;

        // Calculate exact price
        uint256 totalPrice = renewalContract.bulkRentPrice(labels, durations);

        uint256 renewerBalanceBefore = renewer.balance;

        // Bulk renew - pre-existing balance should be refunded too
        renewalContract.bulkRenew{value: totalPrice}(labels, durations);

        // Renewer should receive pre-existing balance as refund
        uint256 renewerBalanceAfter = renewer.balance;
        assertEq(
            renewerBalanceAfter,
            renewerBalanceBefore - totalPrice + excessBalance,
            "Renewer should receive pre-existing contract balance as refund"
        );

        // Contract should have no remaining balance
        assertEq(address(renewalContract).balance, 0, "Contract should have no remaining balance");
    }

    function test_bulkRenew_eventsEmittedInOrder() public {
        string[] memory labels = new string[](3);
        uint256[] memory durations = new uint256[](3);
        labels[0] = TEST_WRAPPED_LABEL;
        labels[1] = TEST_UNWRAPPED_LABEL;
        labels[2] = TEST_LEGACY_LABEL;
        durations[0] = TEST_DURATION;
        durations[1] = TEST_DURATION;
        durations[2] = TEST_DURATION;

        uint256 totalPrice = renewalContract.bulkRentPrice(labels, durations);

        // Record logs to verify event order
        vm.recordLogs();

        renewalContract.bulkRenew{value: totalPrice}(labels, durations);

        // Get recorded logs
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Count RenewalReferred events
        uint256 renewalReferredCount = 0;
        bytes32 renewalReferredTopic = keccak256("RenewalReferred(string,bytes32,uint256,uint256,bytes32)");

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == renewalReferredTopic) {
                renewalReferredCount++;
            }
        }

        assertEq(renewalReferredCount, 3, "Should emit exactly 3 RenewalReferred events");
    }

    function test_bulkRenew_wrappedNameExpiryUpdated() public {
        string[] memory labels = new string[](1);
        uint256[] memory durations = new uint256[](1);
        labels[0] = TEST_WRAPPED_LABEL;
        durations[0] = TEST_DURATION;

        bytes32 node = NameCoder.namehash(NameCoder.encode(string.concat(TEST_WRAPPED_LABEL, ".eth")), 0);
        uint256 tokenId = uint256(node);

        // Assert is wrapped
        assertEq(NAME_WRAPPER.isWrapped(node), true, "TEST_WRAPPED_LABEL should be in NameWrapper");

        // Get initial wrapped expiry
        (,, uint64 initialWrappedExpiry) = NAME_WRAPPER.getData(tokenId);

        // Calculate price and renew
        uint256 totalPrice = renewalContract.bulkRentPrice(labels, durations);
        renewalContract.bulkRenew{value: totalPrice}(labels, durations);

        // Assert NameWrapper expiry updated
        (,, uint64 newWrappedExpiry) = NAME_WRAPPER.getData(tokenId);
        assertEq(newWrappedExpiry, initialWrappedExpiry + TEST_DURATION, "NameWrapper expiry should be updated");
    }

    function test_bulkRenew_mixedWrappedAndUnwrappedNames() public {
        string[] memory labels = new string[](2);
        uint256[] memory durations = new uint256[](2);
        labels[0] = TEST_WRAPPED_LABEL; // wrapped
        labels[1] = TEST_UNWRAPPED_LABEL; // unwrapped
        durations[0] = TEST_DURATION;
        durations[1] = TEST_DURATION;

        // Get initial expiries from BaseRegistrar
        uint256 initialWrappedExpiry = BASE_REGISTRAR.nameExpires(uint256(keccak256(bytes(TEST_WRAPPED_LABEL))));
        uint256 initialUnwrappedExpiry = BASE_REGISTRAR.nameExpires(uint256(keccak256(bytes(TEST_UNWRAPPED_LABEL))));

        // Calculate price and renew
        uint256 totalPrice = renewalContract.bulkRentPrice(labels, durations);
        renewalContract.bulkRenew{value: totalPrice}(labels, durations);

        // Assert both expiries updated
        uint256 newWrappedExpiry = BASE_REGISTRAR.nameExpires(uint256(keccak256(bytes(TEST_WRAPPED_LABEL))));
        uint256 newUnwrappedExpiry = BASE_REGISTRAR.nameExpires(uint256(keccak256(bytes(TEST_UNWRAPPED_LABEL))));

        assertEq(newWrappedExpiry, initialWrappedExpiry + TEST_DURATION, "Wrapped name expiry should be updated");
        assertEq(newUnwrappedExpiry, initialUnwrappedExpiry + TEST_DURATION, "Unwrapped name expiry should be updated");
    }

    function test_bulkRenew_largerBatch() public {
        // Test with a larger batch to ensure gas efficiency and correctness
        string[] memory labels = new string[](3);
        uint256[] memory durations = new uint256[](3);

        // Use all three test names
        labels[0] = TEST_WRAPPED_LABEL;
        labels[1] = TEST_UNWRAPPED_LABEL;
        labels[2] = TEST_LEGACY_LABEL;

        // Different durations for variety
        durations[0] = 365 days;
        durations[1] = 365 days * 2;
        durations[2] = 365 days * 3;

        // Store initial expiries
        uint256[] memory initialExpiries = new uint256[](3);
        for (uint256 i = 0; i < 3; i++) {
            initialExpiries[i] = BASE_REGISTRAR.nameExpires(uint256(keccak256(bytes(labels[i]))));
        }

        // Calculate and execute bulk renewal
        uint256 totalPrice = renewalContract.bulkRentPrice(labels, durations);
        renewalContract.bulkRenew{value: totalPrice}(labels, durations);

        // Verify all names renewed correctly
        for (uint256 i = 0; i < 3; i++) {
            uint256 newExpiry = BASE_REGISTRAR.nameExpires(uint256(keccak256(bytes(labels[i]))));
            assertEq(
                newExpiry,
                initialExpiries[i] + durations[i],
                string.concat("Name ", labels[i], " should have correct new expiry")
            );
        }
    }
}

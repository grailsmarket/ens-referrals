//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

interface IBulkRenewalWithReferral {
    function bulkRentPrice(
        string[] calldata labels,
        uint256[] calldata durations
    ) external view returns (uint256 total);

    function bulkRenew(
        string[] calldata labels,
        uint256[] calldata durations
    ) external payable;
}

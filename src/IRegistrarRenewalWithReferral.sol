//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

interface IRegistrarRenewalWithReferral {
    function renew(string calldata label, uint256 duration, bytes32 referrer) external payable;

    function bulkRentPrice(
        string[] calldata labels,
        uint256[] calldata durations
    ) external view returns (uint256 total);

    function bulkRenew(
        string[] calldata labels,
        uint256[] calldata durations,
        bytes32 referrer
    ) external payable;
}

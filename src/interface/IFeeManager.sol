// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./ILedgerComponent.sol";

interface IFeeManager is ILedgerComponent {
    error InvalidFeeCollectorType();

    // Fee collector type definition
    enum FeeCollectorType {
        None,
        WithdrawFeeCollector,
        FuturesFeeCollector
    }

    // Event for fee collector change
    event ChangeFeeCollector(
        FeeCollectorType indexed feeCollectorType, bytes32 oldFeeCollector, bytes32 newFeeCollector
    );

    function initialize() external;

    function getFeeCollector(FeeCollectorType feeCollectorType) external returns (bytes32);
    function changeFeeCollector(FeeCollectorType feeCollectorType, bytes32 _newCollector) external;
}

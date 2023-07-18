// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./ILedgerComponent.sol";

interface IFeeManager is ILedgerComponent {
    error InvalidFeeCollectorType();

    enum FeeCollectorType {
        None,
        TradingFeeCollector,
        OperatorGasFeeCollector,
        FuturesFeeCollector
    }

    event ChangeFeeCollector(FeeCollectorType feeCollectorType, bytes32 oldFeeCollector, bytes32 newFeeCollector);

    function initialize() external;

    function getFeeCollector(FeeCollectorType feeCollectorType) external returns (bytes32);
    function changeFeeCollector(FeeCollectorType feeCollectorType, bytes32 _newCollector) external;
}

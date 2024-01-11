// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./ILedgerComponent.sol";

interface IFeeManager is ILedgerComponent {
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

    event ChangeBrokerAccountId(bytes32 oldBrokerAccountId, bytes32 newBrokerAccountId);

    function initialize() external;

    function getFeeCollector(FeeCollectorType feeCollectorType) external returns (bytes32);
    function changeFeeCollector(FeeCollectorType feeCollectorType, bytes32 _newCollector) external;

    function setBrokerAccountId(bytes32 brokerId, bytes32 brokerAccountId) external;
}

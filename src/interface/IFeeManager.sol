// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./ILedgerComponent.sol";

interface IFeeManager is ILedgerComponent {
    error InvalidFeeCollectorType();

    enum FeeCollectorType {
        TradingFeeCollector,
        OperatorGasFeeCollector,
        FuturesFeeCollector
    }

    function getOperatorGasFeeBalance(bytes32 tokenHash) external returns (uint256);
    function setOperatorGasFeeBalance(bytes32 tokenHash, uint256 amount) external;
    function getFeeAmount() external returns (uint256);
    function changeFeeAmount(uint256 amount) external;
    function getFeeCollector(FeeCollectorType feeCollectorType) external returns (bytes32);
    function changeFeeCollector(FeeCollectorType feeCollectorType, bytes32 _newCollector) external;
}

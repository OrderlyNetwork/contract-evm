// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./interface/IFeeManager.sol";
import "./LedgerComponent.sol";

contract FeeManager is IFeeManager, LedgerComponent {
    // accountId
    bytes32 public tradingFeeCollector;
    // accountId
    bytes32 public operatorGasFeeCollector;
    // accountId
    bytes32 public futuresFeeCollector;

    constructor() {
        _disableInitializers();
    }

    function initialize() public override initializer {
        __Ownable_init();
    }

    // get_fee_collector
    function getFeeCollector(FeeCollectorType feeCollectorType) public view override returns (bytes32) {
        if (feeCollectorType == FeeCollectorType.TradingFeeCollector) {
            return tradingFeeCollector;
        } else if (feeCollectorType == FeeCollectorType.OperatorGasFeeCollector) {
            return operatorGasFeeCollector;
        } else if (feeCollectorType == FeeCollectorType.FuturesFeeCollector) {
            return futuresFeeCollector;
        }
        revert InvalidFeeCollectorType();
    }

    // change_fee_collector
    function changeFeeCollector(FeeCollectorType feeCollectorType, bytes32 _newCollector) public override onlyOwner {
        if (feeCollectorType == FeeCollectorType.TradingFeeCollector) {
            emit ChangeFeeCollector(feeCollectorType, tradingFeeCollector, _newCollector);
            tradingFeeCollector = _newCollector;
        } else if (feeCollectorType == FeeCollectorType.OperatorGasFeeCollector) {
            emit ChangeFeeCollector(feeCollectorType, operatorGasFeeCollector, _newCollector);
            operatorGasFeeCollector = _newCollector;
        } else if (feeCollectorType == FeeCollectorType.FuturesFeeCollector) {
            emit ChangeFeeCollector(feeCollectorType, futuresFeeCollector, _newCollector);
            futuresFeeCollector = _newCollector;
        }
    }
}

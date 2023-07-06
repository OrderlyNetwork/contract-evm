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
    // amount
    uint128 public withdrawFeeAmount;
    // tokenHash => amount
    mapping(bytes32 => uint128) public operatorGasFeeBalances;

    constructor() {
        _disableInitializers();
    }

    function initialize() public override initializer {
        __Ownable_init();
    }

    // get_operator_gas_fee_balance
    function getOperatorGasFeeBalance(bytes32 tokenHash) external view override returns (uint128) {
        return operatorGasFeeBalances[tokenHash];
    }

    // set_operator_gas_fee_balance
    function setOperatorGasFeeBalance(bytes32 tokenHash, uint128 amount) external override onlyLedger {
        operatorGasFeeBalances[tokenHash] = amount;
    }

    // get_fee_amount
    function getFeeAmount() external view override returns (uint128) {
        return withdrawFeeAmount;
    }

    // change_fee_amount
    // WIP scope
    function changeFeeAmount(uint128 amount) external override onlyOwner {
        withdrawFeeAmount = amount;
    }

    // get_fee_collector
    function getFeeCollector(FeeCollectorType feeCollectorType) external view override returns (bytes32) {
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
    // WIP scope
    function changeFeeCollector(FeeCollectorType feeCollectorType, bytes32 _newCollector) external override onlyOwner {
        if (feeCollectorType == FeeCollectorType.TradingFeeCollector) {
            tradingFeeCollector = _newCollector;
        } else if (feeCollectorType == FeeCollectorType.OperatorGasFeeCollector) {
            operatorGasFeeCollector = _newCollector;
        } else if (feeCollectorType == FeeCollectorType.FuturesFeeCollector) {
            futuresFeeCollector = _newCollector;
        }
    }
}

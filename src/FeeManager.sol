// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./interface/IFeeManager.sol";
import "./LedgerComponent.sol";

contract FeeManager is IFeeManager, LedgerComponent {
    // accountId
    bytes32 public withdrawFeeCollector;
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
        if (feeCollectorType == FeeCollectorType.WithdrawFeeCollector) {
            return withdrawFeeCollector;
        } else if (feeCollectorType == FeeCollectorType.FuturesFeeCollector) {
            return futuresFeeCollector;
        }
        revert InvalidFeeCollectorType();
    }

    // change_fee_collector
    function changeFeeCollector(FeeCollectorType feeCollectorType, bytes32 _newCollector) public override onlyOwner {
        if (feeCollectorType == FeeCollectorType.WithdrawFeeCollector) {
            emit ChangeFeeCollector(feeCollectorType, withdrawFeeCollector, _newCollector);
            withdrawFeeCollector = _newCollector;
        } else if (feeCollectorType == FeeCollectorType.FuturesFeeCollector) {
            emit ChangeFeeCollector(feeCollectorType, futuresFeeCollector, _newCollector);
            futuresFeeCollector = _newCollector;
        }
    }
}

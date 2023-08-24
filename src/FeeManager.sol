// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./interface/IFeeManager.sol";
import "./LedgerComponent.sol";

/**
 * FeeManager saves FeeCollector accountId
 */
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
        // https://wootraders.atlassian.net/jira/software/c/projects/ORDOPS/boards/102?modal=detail&selectedIssue=ORDOPS-264
        futuresFeeCollector = 0x2d7f165afa581711dec503b332511d3e9691068e03bd66cca63dadcc5a26e91f;
        withdrawFeeCollector = 0x62acc78595f76ee3ab5309bcfee3fec4cb3fd7686a4a2cd06b77ce1a12946f33;
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

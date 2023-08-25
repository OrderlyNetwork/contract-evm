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
        futuresFeeCollector = 0x9bbb758b076a7da7ca659696e5625b4d4c362f228e8351be705ef75e581aef9f;
        withdrawFeeCollector = 0xf2ceee2895558bc575e28fa342a9f708f929a8e99a4819aa9ef32d114b7924a5;
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

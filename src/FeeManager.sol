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
        // https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/346882377/System+Account+-+V2
        futuresFeeCollector = 0x0ded76d9b80cba463c51e8d556fda7ae63458e8fc1d912ae87ecae5ceb4f5d03;
        withdrawFeeCollector = 0xd24181b51223b8998dba9fd230a053034dd7d0140c3a50c57c806def77992663;
    }

    // Get the fee collector account id according to the fee collector type
    function getFeeCollector(FeeCollectorType feeCollectorType) public view override returns (bytes32) {
        if (feeCollectorType == FeeCollectorType.WithdrawFeeCollector) {
            return withdrawFeeCollector;
        } else if (feeCollectorType == FeeCollectorType.FuturesFeeCollector) {
            return futuresFeeCollector;
        }
        revert InvalidFeeCollectorType();
    }

    // Change the fee collector account id according to the fee collector type
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

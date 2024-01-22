// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./interface/IFeeManager.sol";
import "./LedgerComponent.sol";

/// @title FeeManager component for Ledger contract
/// @author Orderly_Rubick
/// @notice FeeManager saves FeeCollector accountId, both getter and setter
contract FeeManager is IFeeManager, LedgerComponent {
    // accountId
    bytes32 public withdrawFeeCollector;
    // accountId
    bytes32 public futuresFeeCollector;
    // broker fee accountId
    mapping(bytes32 => bytes32) public brokerHash2BrokerAccountId;

    constructor() {
        _disableInitializers();
    }

    function initialize() external override(IFeeManager, LedgerComponent) initializer {
        __Ownable_init();
        // https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/346882377/System+Account+-+V2
        futuresFeeCollector = 0x0ded76d9b80cba463c51e8d556fda7ae63458e8fc1d912ae87ecae5ceb4f5d03;
        withdrawFeeCollector = 0xd24181b51223b8998dba9fd230a053034dd7d0140c3a50c57c806def77992663;
    }

    /// @notice Get the fee collector account id according to the fee collector type
    /// @param feeCollectorType The fee collector type
    /// @return The fee collector account id
    function getFeeCollector(FeeCollectorType feeCollectorType) external view override returns (bytes32) {
        if (feeCollectorType == FeeCollectorType.WithdrawFeeCollector) {
            return withdrawFeeCollector;
        } else if (feeCollectorType == FeeCollectorType.FuturesFeeCollector) {
            return futuresFeeCollector;
        }
        revert InvalidFeeCollectorType();
    }

    /// @notice Change the fee collector account id according to the fee collector type
    /// @param feeCollectorType The fee collector type
    /// @param _newCollector The new fee collector account id
    function changeFeeCollector(FeeCollectorType feeCollectorType, bytes32 _newCollector) public override onlyOwner {
        if (feeCollectorType == FeeCollectorType.WithdrawFeeCollector) {
            emit ChangeFeeCollector(feeCollectorType, withdrawFeeCollector, _newCollector);
            withdrawFeeCollector = _newCollector;
        } else if (feeCollectorType == FeeCollectorType.FuturesFeeCollector) {
            emit ChangeFeeCollector(feeCollectorType, futuresFeeCollector, _newCollector);
            futuresFeeCollector = _newCollector;
        } else {
            revert InvalidFeeCollectorType();
        }
    }

    /// @notice Set the broker fee account id
    /// @param brokerHash The broker id
    /// @param brokerAccountId The broker fee account id
    function setBrokerAccountId(bytes32 brokerHash, bytes32 brokerAccountId) external override onlyOwner {
        if (brokerHash == bytes32(0) || brokerAccountId == bytes32(0)) revert Bytes32Zero();
        emit ChangeBrokerAccountId(brokerHash2BrokerAccountId[brokerHash], brokerAccountId);
        brokerHash2BrokerAccountId[brokerHash] = brokerAccountId;
    }
}

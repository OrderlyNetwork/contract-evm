// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "./dataLayout/OperatorManagerDataLayout.sol";
import "./interface/IOperatorManagerImplB.sol";
import "./library/Signature.sol";

/// @title OperatorManager contract, implementation part B contract, for resolve EIP170 limit
/// @author Orderly_Rubick
contract OperatorManagerImplB is IOperatorManagerImplB, OwnableUpgradeable, OperatorManagerDataLayout {
    constructor() {
        _disableInitializers();
    }

    /// @notice Function for event upload
    function eventUpload(EventTypes.EventUpload calldata data) external override {
        if (data.batchId != eventUploadBatchId) revert BatchIdNotMatch(data.batchId, eventUploadBatchId);
        _innerPing();
        _eventUploadData(data);
        // emit event
        emit EventUpload(data.batchId);
        // next wanted eventUploadBatchId
        eventUploadBatchId += 1;
    }

    /// @notice Function to verify Engine signature for event upload data, if validated then Ledger contract will be called to execute the event process
    function _eventUploadData(EventTypes.EventUpload calldata data) internal {
        EventTypes.EventUploadData[] calldata events = data.events; // gas saving
        if (events.length != data.count) revert CountNotMatch(events.length, data.count);

        // check engine signature
        bool succ = Signature.eventsUploadEncodeHashVerify(data, engineEventUploadAddress);
        if (!succ) revert SignatureNotMatch();

        // process each event upload
        for (uint256 i = 0; i < data.count; i++) {
            _processEventUpload(events[i]);
        }
    }

    /// @notice Cross-Contract call to Ledger contract to process each event upload according to the event type
    function _processEventUpload(EventTypes.EventUploadData calldata data) internal {
        uint8 bizType = data.bizType;
        if (bizType == 1) {
            // withdraw
            ledger.executeWithdrawAction(abi.decode(data.data, (EventTypes.WithdrawData)), data.eventId);
        } else if (bizType == 2) {
            // settlement
            ledger.executeSettlement(abi.decode(data.data, (EventTypes.Settlement)), data.eventId);
        } else if (bizType == 3) {
            // adl
            ledger.executeAdl(abi.decode(data.data, (EventTypes.Adl)), data.eventId);
        } else if (bizType == 4) {
            // liquidation
            ledger.executeLiquidation(abi.decode(data.data, (EventTypes.Liquidation)), data.eventId);
        } else if (bizType == 5) {
            // fee disuribution
            ledger.executeFeeDistribution(abi.decode(data.data, (EventTypes.FeeDistribution)), data.eventId);
        } else if (bizType == 6) {
            // delegate signer
            ledger.executeDelegateSigner(abi.decode(data.data, (EventTypes.DelegateSigner)), data.eventId);
        } else if (bizType == 7) {
            // delegate withdraw
            ledger.executeDelegateWithdrawAction(abi.decode(data.data, (EventTypes.WithdrawData)), data.eventId);
        } else if (bizType == 8) {
            // adl v2
            ledger.executeAdlV2(abi.decode(data.data, (EventTypes.AdlV2)), data.eventId);
        } else if (bizType == 9) {
            // liquidation v2
            ledger.executeLiquidationV2(abi.decode(data.data, (EventTypes.LiquidationV2)), data.eventId);
        } else if (bizType == 10) {
            // withdraw sol
            ledger.executeWithdrawSolAction(abi.decode(data.data, (EventTypes.WithdrawDataSol)), data.eventId);
        } else if (bizType == 11) {
            // withdraw to vault contract
            ledger.executeWithdraw2Contract(abi.decode(data.data, (EventTypes.Withdraw2Contract)), data.eventId);
        } else {
            revert InvalidBizType(bizType);
        }
    }

    /// @notice Function to update last operator interaction timestamp
    function _innerPing() internal {
        lastOperatorInteraction = block.timestamp;
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./interface/ISettlement.sol";
import "./interface/IOperatorManager.sol";
import "./library/signature.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * OperatorManager is responsible for executing cefi tx, only called by operator.
 * This contract should only have one in main-chain (avalanche)
 */
contract OperatorManager is IOperatorManager, Ownable {
    // operator address
    address public operator;
    ISettlement public settlement;

    // ids
    // futuresUploadBatchId
    uint256 public futuresUploadBatchId;
    // eventUploadBatchId
    uint256 public eventUploadBatchId;

    // only operator
    modifier onlyOperator() {
        require(msg.sender == operator, "only operator can call");
        _;
    }

    // constructor
    constructor(address _operator) {
        operator = _operator;
    }

    // entry point for operator to call this contract
    function operatorExecuteAction(OperatorTypes.OperatorActionData actionData, bytes calldata action)
        public
        override
        onlyOperator
    {
        if (actionData == OperatorTypes.OperatorActionData.FuturesTradeUpload) {
            // FuturesTradeUpload
            futuresTradeUploadData(abi.decode(action, (PrepTypes.FuturesTradeUploadData)));
        } else if (actionData == OperatorTypes.OperatorActionData.EventUpload) {
            // EventUpload
            eventUploadData(abi.decode(action, (PrepTypes.EventUpload)));
        } else if (actionData == OperatorTypes.OperatorActionData.UserRegister) {
            // UserRegister
            settlement.accountRegister(abi.decode(action, (AccountTypes.AccountRegister)));
        } else if (actionData == OperatorTypes.OperatorActionData.UserDeposit) {
            // UserDeposit
            settlement.accountDeposit(abi.decode(action, (AccountTypes.AccountDeposit)));
        } else {
            revert("invalid action data");
        }
    }

    // futures trade upload data
    function futuresTradeUploadData(PrepTypes.FuturesTradeUploadData memory data) internal {
        require(data.batchId == futuresUploadBatchId, "batchId not match");
        PrepTypes.FuturesTradeUpload[] memory trades = data.trades; // gas saving
        require(trades.length == data.count, "count not match");
        _validatePerp(trades);
        // process each validated perp trades
        for (uint256 i = 0; i < data.count; i++) {
            _processValidatedFutures(trades[i]);
        }
        // update_futuresUploadBatchId
        // TODO use math safe add
        futuresUploadBatchId += 1;
    }

    // validate futres trade upload data
    function _validatePerp(PrepTypes.FuturesTradeUpload[] memory trades) internal pure {
        for (uint256 i = 0; i < trades.length; i++) {
            // first, check signature is valid
            _verifySignature(trades[i]);
            // second, check symbol (and maybe other value) is valid
            // TODO
        }
    }

    function _verifySignature(PrepTypes.FuturesTradeUpload memory trade) internal pure {
        // TODO ensure the parameters satisfy the real signature
        bytes32 sig = keccak256(abi.encodePacked(trade.tradeId, trade.symbol, trade.side, trade.tradeQty));

        require(
            Signature.verify(Signature.getEthSignedMessageHash(sig), trade.signature, trade.addr), "invalid signature"
        );
    }

    // process each validated perp trades
    function _processValidatedFutures(PrepTypes.FuturesTradeUpload memory trade) internal {
        settlement.updateUserLedgerByTradeUpload(trade);
    }

    // event upload data
    function eventUploadData(PrepTypes.EventUpload memory data) internal {
        require(data.batchId == eventUploadBatchId, "batchId not match");
        PrepTypes.EventUploadData[] memory events = data.events; // gas saving
        require(events.length == data.count, "count not match");
        // process each event upload
        for (uint256 i = 0; i < data.count; i++) {
            _processEventUpload(events[i]);
        }
        // update_eventUploadBatchId
        // TODO use math safe add
        eventUploadBatchId += 1;
    }

    // process each event upload
    function _processEventUpload(PrepTypes.EventUploadData memory data) internal {
        uint256 index_withdraw = 0;
        uint256 index_settlement = 0;
        uint256 index_liquidation = 0;
        // iterate sequence to process each event. The sequence decides the event type.
        for (uint256 i = 0; i < data.sequence.length; i++) {
            if (data.sequence[i] == 0) {
                // withdraw
                settlement.executeWithdrawAction(data.withdraws[index_withdraw], data.eventId);
                index_withdraw += 1;
            } else if (data.sequence[i] == 1) {
                // settlement
                settlement.executeSettlement(data.settlements[index_settlement], data.eventId);
                index_settlement += 1;
            } else if (data.sequence[i] == 2) {
                // liquidation
                settlement.executeLiquidation(data.liquidations[index_liquidation], data.eventId);
                index_liquidation += 1;
            } else {
                revert("invalid sequence");
            }
        }
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./interface/ISettlement.sol";
import "./interface/IOperatorManager.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * OperatorManager is responsible for executing cefi tx, only called by operator.
 * This contract should only have one in main-chain (avalanche)
 */
contract OperatorManager is IOperatorManager, Ownable {
    // operator address
    address public operator;
    // settlement Interface
    ISettlement public settlement;

    // ids
    // futuresUploadBatchId
    uint256 public futuresUploadBatchId;
    // eventUploadBatchId
    uint256 public eventUploadBatchId;
    // last operator interaction timestamp
    uint256 public lastOperatorInteraction;

    // only operator
    modifier onlyOperator() {
        require(msg.sender == operator, "only operator can call");
        _;
    }

    // set operator
    function setOperator(address _operator) public onlyOwner {
        operator = _operator;
    }

    // set settlement
    function setSettlement(address _settlement) public onlyOwner {
        settlement = ISettlement(_settlement);
    }

    // constructor
    // call `setSettlement` later
    constructor(address _operator) {
        operator = _operator;
    }

    // operator ping
    function operatorPing() public onlyOperator {
        _innerPing();
    }

    // entry point for operator to call this contract
    function operatorExecuteAction(OperatorTypes.OperatorActionData actionData, bytes calldata action)
        public
        override
        onlyOperator
    {
        _innerPing();
        if (actionData == OperatorTypes.OperatorActionData.FuturesTradeUpload) {
            // FuturesTradeUpload
            futuresTradeUploadData(abi.decode(action, (PerpTypes.FuturesTradeUploadData)));
        } else if (actionData == OperatorTypes.OperatorActionData.EventUpload) {
            // EventUpload
            eventUploadData(abi.decode(action, (PerpTypes.EventUpload)));
        } else if (actionData == OperatorTypes.OperatorActionData.UserRegister) {
            // UserRegister
            settlement.accountRegister(abi.decode(action, (AccountTypes.AccountRegister)));
        } else {
            revert("invalid action data");
        }
    }

    // accountRegisterAction
    function accountRegisterAction(AccountTypes.AccountRegister calldata data) public override onlyOperator {
        _innerPing();
        settlement.accountRegister(data);
    }

    // futuresTradeUploadDataAction
    function futuresTradeUploadDataAction(PerpTypes.FuturesTradeUploadData calldata data)
        public
        override
        onlyOperator
    {
        _innerPing();
        futuresTradeUploadData(data);
    }

    // eventUploadDataAction
    function eventUploadDataAction(PerpTypes.EventUpload calldata data) public override onlyOperator {
        _innerPing();
        eventUploadData(data);
    }

    // futures trade upload data
    function futuresTradeUploadData(PerpTypes.FuturesTradeUploadData memory data) internal {
        require(data.batchId == futuresUploadBatchId, "batchId not match");
        PerpTypes.FuturesTradeUpload[] memory trades = data.trades; // gas saving
        require(trades.length == data.count, "count not match");
        _validatePerp(trades);
        // process each validated perp trades
        for (uint256 i = 0; i < data.count; i++) {
            _processValidatedFutures(trades[i]);
        }
        // update_futuresUploadBatchId
        futuresUploadBatchId += 1;
    }

    // validate futres trade upload data
    function _validatePerp(PerpTypes.FuturesTradeUpload[] memory trades) internal pure {
        for (uint256 i = 0; i < trades.length; i++) {
            // check symbol (and maybe other value) is valid
            // TODO
        }
    }

    // process each validated perp trades
    function _processValidatedFutures(PerpTypes.FuturesTradeUpload memory trade) internal {
        settlement.updateUserLedgerByTradeUpload(trade);
    }

    // event upload data
    function eventUploadData(PerpTypes.EventUpload memory data) internal {
        require(data.batchId == eventUploadBatchId, "batchId not match");
        PerpTypes.EventUploadData[] memory events = data.events; // gas saving
        require(events.length == data.count, "count not match");
        // process each event upload
        for (uint256 i = 0; i < data.count; i++) {
            _processEventUpload(events[i]);
        }
        // update_eventUploadBatchId
        eventUploadBatchId += 1;
    }

    // process each event upload
    function _processEventUpload(PerpTypes.EventUploadData memory data) internal {
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

    function _innerPing() internal {
        lastOperatorInteraction = block.timestamp;
    }

    function checkCefiDown() public view override returns (bool) {
        return (lastOperatorInteraction + 1 days > block.timestamp);
    }
}

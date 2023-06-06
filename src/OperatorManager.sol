// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./interface/ILedger.sol";
import "./interface/IOperatorManager.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * OperatorManager is responsible for executing cefi tx, only called by operator.
 * This contract should only have one in main-chain (avalanche)
 */
contract OperatorManager is IOperatorManager, Ownable {
    // operator address
    address public operator;
    // ledger Interface
    ILedger public ledger;

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

    // set ledger
    function setLedger(address _ledger) public onlyOwner {
        ledger = ILedger(_ledger);
    }

    // operator ping
    function operatorPing() public onlyOperator {
        _innerPing();
    }

    // @deprecated entry point for operator to call this contract
    function operatorExecuteAction(OperatorTypes.OperatorActionData actionData, bytes calldata action)
        public
        override
        onlyOperator
    {
        _innerPing();
        if (actionData == OperatorTypes.OperatorActionData.FuturesTradeUpload) {
            // FuturesTradeUpload
            _futuresTradeUploadData(abi.decode(action, (PerpTypes.FuturesTradeUploadData)));
        } else if (actionData == OperatorTypes.OperatorActionData.EventUpload) {
            // EventUpload
            _eventUploadData(abi.decode(action, (PerpTypes.EventUpload)));
        } else {
            revert("invalid action data");
        }
    }

    // futuresTradeUploadDataAction
    function futuresTradeUploadDataAction(PerpTypes.FuturesTradeUploadData calldata data)
        public
        override
        onlyOperator
    {
        _innerPing();
        _futuresTradeUploadData(data);
    }

    // eventUploadDataAction
    function eventUploadDataAction(PerpTypes.EventUpload calldata data) public override onlyOperator {
        _innerPing();
        _eventUploadData(data);
    }

    // futures trade upload data
    function _futuresTradeUploadData(PerpTypes.FuturesTradeUploadData memory data) internal {
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
        ledger.updateUserLedgerByTradeUpload(trade);
    }

    // event upload data
    function _eventUploadData(PerpTypes.EventUpload memory data) internal {
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
        uint256 bizId = data.bizId;
        if (bizId == 0) {
            // withdraw
            ledger.executeWithdrawAction(abi.decode(data.data, (PerpTypes.WithdrawData)), data.eventId);
        } else if (bizId == 1) {
            // ledger
            ledger.executeLedger(abi.decode(data.data, (PerpTypes.LedgerData)), data.eventId);
        } else if (bizId == 2) {
            // liquidation
            ledger.executeLiquidation(abi.decode(data.data, (PerpTypes.LiquidationData)), data.eventId);
        } else {
            revert("invalid bizId");
        }
    }

    function _innerPing() internal {
        lastOperatorInteraction = block.timestamp;
    }

    function checkCefiDown() public view override returns (bool) {
        return (lastOperatorInteraction + 1 days > block.timestamp);
    }
}

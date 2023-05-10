// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./interface/Isettlement.sol";
import "./library/signature.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * OperatorManager is responsible for executing cefi tx, only called by operator.
 * This contract should only have one in main-chain (avalanche)
 */
contract OperatorManager is Ownable {
    // operator address
    address public operator;
    Isettlement public settlement;

    // ids
    // futures_upload_batch_id
    uint256 public futures_upload_batch_id;
    // event_upload_batch_id
    uint256 public event_upload_batch_id;

    // only operator
    modifier onlyOperator() {
        require(msg.sender == operator, "only operator can call");
        _;
    }

    // constructor
    constructor(address _operator) {
        futures_upload_batch_id = 0;
        operator = _operator;
    }

    // entry point for operator to call this contract
    function operator_execute_action(PrepTypes.OperatorActionData action_data, bytes calldata action)
        public
        onlyOperator
    {
        if (action_data == PrepTypes.OperatorActionData.FuturesTradeUpload) {
            // FuturesTradeUpload
            futures_trade_upload_data(abi.decode(action, (PrepTypes.FuturesTradeUploadData)));
        } else if (action_data == PrepTypes.OperatorActionData.EventUpload) {
            // EventUpload
            // TODO
        } else {
            revert("invalid action_data");
        }
    }

    // futures trade upload data
    function futures_trade_upload_data(PrepTypes.FuturesTradeUploadData memory data) internal {
        require(data.batch_id == futures_upload_batch_id, "batch_id not match");
        PrepTypes.FuturesTradeUpload[] memory trades = data.trades; // gas saving
        require(trades.length == data.count, "count not match");
        _validate_perp(trades);
        // process each validated perp trades
        for (uint256 i = 0; i < data.count; i++) {
            _process_validated_futures(trades[i]);
        }
        // update_futures_upload_batch_id
        // TODO use math safe add
        futures_upload_batch_id += 1;
    }

    // validate futres trade upload data
    function _validate_perp(PrepTypes.FuturesTradeUpload[] memory trades) internal pure {
        for (uint256 i = 0; i < trades.length; i++) {
            // first, check signature is valid
            _verify_signature(trades[i]);
            // second, check symbol (and maybe other value) is valid
            // TODO
        }
    }

    function _verify_signature(PrepTypes.FuturesTradeUpload memory trade) internal pure {
        // TODO ensure the parameters satisfy the real signature
        bytes32 sig = keccak256(abi.encodePacked(trade.trade_id, trade.symbol, trade.side, trade.trade_qty));

        require(
            Signature.verify(Signature.getEthSignedMessageHash(sig), trade.signature, trade.addr), "invalid signature"
        );
    }

    // process each validated perp trades
    function _process_validated_futures(PrepTypes.FuturesTradeUpload memory trade) internal {
        settlement.update_user_ledger_by_trade_upload(trade);
    }

    // event upload data
    function event_upload_data(PrepTypes.EventUpload memory data) internal {
        require(data.batch_id == event_upload_batch_id, "batch_id not match");
        PrepTypes.EventUploadData[] memory events = data.events; // gas saving
        require(events.length == data.count, "count not match");
        // process each event upload
        for (uint256 i = 0; i < data.count; i++) {
            _process_event_upload(events[i]);
        }
        // update_event_upload_batch_id
        // TODO use math safe add
        event_upload_batch_id += 1;
    }

    // process each event upload
    function _process_event_upload(PrepTypes.EventUploadData memory data) internal {
        uint256 index_withdraw = 0;
        uint256 index_settlement = 0;
        uint256 index_liquidation = 0;
        // iterate sequence to process each event. The sequence decides the event type.
        for (uint256 i = 0; i < data.sequence.length; i++) {
            if (data.sequence[i] == 0) {
                // withdraw
                settlement.execute_withdraw_action(data.withdraws[index_withdraw], data.event_id);
                index_withdraw += 1;
            } else if (data.sequence[i] == 1) {
                // settlement
                settlement.execute_settlement(data.settlements[index_settlement], data.event_id);
                index_settlement += 1;
            } else if (data.sequence[i] == 2) {
                // liquidation
                settlement.execute_liquidation(data.liquidations[index_liquidation], data.event_id);
                index_liquidation += 1;
            } else {
                revert("invalid sequence");
            }
        }
    }
}

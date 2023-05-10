// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

library PrepTypes {
    enum OperatorActionData {
        None,
        FuturesTradeUpload,
        EventUpload,
        PerpMarketInfo
    }

    // FuturesTradeUploadData

    struct FuturesTradeUploadData {
        uint256 batch_id;
        uint256 count;
        FuturesTradeUpload[] trades;
    }

    struct FuturesTradeUpload {
        uint256 trade_id;
        uint256 match_id;
        address account_id;
        string symbol;
        bool side;
        uint256 trade_qty;
        // signature for validate signed by real user
        bytes signature;
    }

    // EventUpload

    struct EventUpload {
        uint256 batch_id;
        uint256 count;
        EventUploadData[] events;
    }

    struct EventUploadData {
        uint256 event_id;
        string biz_type;
        uint256 biz_id;
        WithdrawData[] withdraws;
        Settlement[] settlements;
        Liquidation[] liquidations;
        uint256[] sequence;
    }

    struct WithdrawData {
        address account_id;
        bytes32 token;
        uint256 withdraw_id;
        bool approval;
        uint256 chain_id; // target withdraw chain
    }

    struct Settlement {
        address account_id;
        int256 settled_amount;
        bytes32 settled_asset;
        uint256 insurance_transfer_amount;
        SettlementExecution[] settlement_executions;
    }

    struct Liquidation {
        address account_id;
        int256 settled_amount;
        LiquidationTransfer[] liquidation_transfers;
        uint256 timestamp;
        bytes32 liquidated_asset;
    }

    struct LiquidationTransfer {
        uint256 liquidation_transfer_id;
        address liquidator_account_id;
        bytes32 list_symbol;
        int256 position_qty_transfer;
        int256 cost_position_transfer;
        uint256 liquidator_fee;
        uint256 insurance_fee;
        uint256 mark_price;
        int256 sum_unitary_fundings;
        uint256 liquidation_fee;
    }

    struct SettlementExecution {
        bytes32 symbol;
        int256 sum_unitary_fundings;
        uint256 mark_price;
        int256 settled_amount;
    }
}

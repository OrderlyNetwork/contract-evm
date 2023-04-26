// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

library Types {
    enum OperatorActionData {
        None,
        FuturesTradeUpload,
        EventUpload,
        PerpMarketInfo
    }

    // FuturesTradeUploadData

    struct FuturesTradeUploadData {
        uint batch_id;
        uint count;
        FuturesTradeUpload[] trades;
    }

    struct FuturesTradeUpload {
        uint trade_id;
        uint match_id;
        address account_id;
        string symbol;
        bool side;
        uint trade_qty;
        // signature for validate signed by real user
        bytes signature;
    }

    // EventUpload

    struct EventUpload {
        uint batch_id;
        uint count;
        EventUploadData[] events;
    }

    struct EventUploadData {
        uint event_id;
        string biz_type;
        uint biz_id;
        WithdrawData[] withdraws;
        Settlement[] settlements;
        Liquidation[] liquidations;
        uint[] sequence;
    }

    struct WithdrawData {
        address account_id;
        uint withdraw_id;
        bool approval;
    }

    struct Settlement {
        address account_id;
        int settled_amount;
        bytes32 settled_asset;
        uint insurance_transfer_amount;
        SettlementExecution[] settlement_executions;
    }

    struct Liquidation {
        address account_id;
        int settled_amount;
        LiquidationTransfer[] liquidation_transfers;
        uint timestamp;
        bytes32 liquidated_asset;
    }

    struct LiquidationTransfer {
        uint liquidation_transfer_id;
        address liquidator_account_id;
        bytes32 list_symbol;
        int position_qty_transfer;
        int cost_position_transfer;
        uint liquidator_fee;
        uint insurance_fee;
        uint mark_price;
        int sum_unitary_fundings;
        uint liquidation_fee;
    }

    struct SettlementExecution {
        bytes32 symbol;
        int sum_unitary_fundings;
        uint mark_price;
        int settled_amount;
    }
}
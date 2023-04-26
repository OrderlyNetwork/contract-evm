// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

library Types {
    enum OperatorActionData {
        None,
        FuturesTradeUpload,
        EventUpload,
        PerpMarketInfo
    }

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
}
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

/// @title PerpTypes library
/// @author Orderly_Rubick
library PerpTypes {
    // FuturesTradeUploadData
    struct FuturesTradeUploadData {
        bytes32 r;
        bytes32 s;
        uint8 v;
        uint64 batchId;
        uint8 count;
        FuturesTradeUpload[] trades;
    }

    struct FuturesTradeUpload {
        bytes32 accountId;
        bytes32 symbolHash;
        bytes32 feeAssetHash;
        int128 tradeQty;
        int128 notional;
        uint128 executedPrice;
        int128 fee;
        int128 sumUnitaryFundings;
        uint64 tradeId;
        uint64 matchId;
        uint64 timestamp;
        bool side; // buy (false) or sell (true)
    }
}

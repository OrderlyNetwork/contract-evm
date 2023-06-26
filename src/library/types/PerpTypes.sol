// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

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
        uint64 tradeId;
        uint64 matchId;
        bytes32 accountId;
        bytes32 symbolHash;
        bool side; // buy (false) or sell (true)
        int128 tradeQty;
        int128 notional;
        uint128 executedPrice;
        uint128 fee;
        bytes32 feeAssetHash;
        int128 sumUnitaryFundings;
        uint64 timestamp;
    }
}

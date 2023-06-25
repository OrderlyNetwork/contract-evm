// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

library PerpTypes {
    // FuturesTradeUploadData
    struct FuturesTradeUploadData {
        uint64 batchId;
        uint8 count;
        FuturesTradeUpload[] trades;
    }

    struct FuturesTradeUpload {
        uint64 tradeId;
        string matchId;
        bytes32 accountId;
        bytes32 symbolHash;
        bool side;
        int128 tradeQty;
        int128 sumUnitaryFundings;
        uint128 executedPrice;
        int128 notional;
        uint128 fee;
        bytes32 feeAssetHash;
        uint64 timestamp;
    }
}

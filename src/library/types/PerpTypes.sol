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
        int256 tradeQty;
        int256 sumUnitaryFundings;
        uint256 executedPrice;
        int256 notional;
        uint256 fee;
        bytes32 feeAssetHash;
        uint64 timestamp;
    }
}

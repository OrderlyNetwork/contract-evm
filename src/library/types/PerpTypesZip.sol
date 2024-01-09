// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

/// @title PerpTypesZip library
/// @author Orderly_Rubick
/// @notice This library is the smaller version of PerpTypes library, used for decompressing calldata size
library PerpTypesZip {
    // FuturesTradeUploadDataZip
    struct FuturesTradeUploadDataZip {
        bytes32 r;
        bytes32 s;
        uint8 v;
        uint64 batchId;
        uint8 count;
        FuturesTradeUploadZip[] trades;
    }

    struct FuturesTradeUploadZip {
        bytes32 accountId;
        uint8 symbolId;
        int128 tradeQty;
        uint128 executedPrice;
        int128 fee;
        int128 sumUnitaryFundings;
        uint64 tradeId;
        uint64 matchId;
        uint64 timestamp;
    }
}

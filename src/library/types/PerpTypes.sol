// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

library PerpTypes {
    // FuturesTradeUploadData
    struct FuturesTradeUploadData {
        uint256 batchId;
        uint256 count;
        FuturesTradeUpload[] trades;
    }

    struct FuturesTradeUpload {
        uint256 tradeId;
        uint256 matchId;
        bytes32 accountId;
        address addr;
        string symbol;
        bool side;
        uint256 tradeQty;
        // signature for validate signed by real user
        bytes signature;
    }
}

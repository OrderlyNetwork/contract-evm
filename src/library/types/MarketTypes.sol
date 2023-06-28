// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

library MarketTypes {
    struct PerpMarketCfg {
        uint32 baseMaintenanceMargin;
        uint32 baseInitialMargin;
        uint128 liquidationFeeMax;
        uint128 markPrice;
        uint128 indexPriceOrderly;
        int128 sumUnitaryFundings;
        uint256 lastMarkPriceUpdated;
        uint256 lastFundingUpdated;
    }

    // WIP: change me
    struct PerpMarketUpload {
        uint8 bizType;
        bytes data;
    }

    struct PerpPriceInner {
        uint64 maxTimestamp;
        PerpPrice[] perpPrices;
    }

    struct SumUnitaryFundingsInner {
        uint64 maxTimestamp;
        SumUnitaryFunding[] sumUnitaryFundings;
    }

    struct PerpPrice {
        uint128 indexPrice;
        uint128 markPrice;
        bytes32 symbolHash;
        uint64 timestamp;
    }

    struct SumUnitaryFunding {
        int128 sumUnitaryFunding;
        bytes32 symbolHash;
        uint64 timestamp;
    }
}

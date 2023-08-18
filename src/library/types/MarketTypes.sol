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

    struct UploadPerpPrice {
        bytes32 r;
        bytes32 s;
        uint8 v;
        uint64 maxTimestamp;
        PerpPrice[] perpPrices;
    }

    struct UploadSumUnitaryFundings {
        bytes32 r;
        bytes32 s;
        uint8 v;
        uint64 maxTimestamp;
        SumUnitaryFunding[] sumUnitaryFundings;
    }

    struct PerpPrice {
        bytes32 symbolHash;
        uint128 indexPrice;
        uint128 markPrice;
        uint64 timestamp;
    }

    struct SumUnitaryFunding {
        bytes32 symbolHash;
        int128 sumUnitaryFunding;
        uint64 timestamp;
    }
}

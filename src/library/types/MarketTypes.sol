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
        uint64 lastMarkPriceUpdated;
        uint64 lastFundingUpdated;
    }
}

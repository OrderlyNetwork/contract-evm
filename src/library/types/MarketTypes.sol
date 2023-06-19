// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

library MarketTypes {
    struct PerpMarketCfg {
        uint32 baseMaintenanceMargin;
        uint32 baseInitialMargin;
        uint256 liquidationFeeMax;
        uint256 markPrice;
        uint256 indexPriceOrderly;
        int256 sumUnitaryFundings;
        uint64 lastMarkPriceUpdated;
        uint64 lastFundingUpdated;
    }
}

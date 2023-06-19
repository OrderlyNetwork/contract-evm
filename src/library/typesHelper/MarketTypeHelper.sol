// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../types/MarketTypes.sol";

library MarketTypeHelper {
    function setBaseMaintenanceMargin(MarketTypes.PerpMarketCfg storage _perpMarketCfg, uint32 _baseMaintenanceMargin)
        internal
    {
        _perpMarketCfg.baseMaintenanceMargin = _baseMaintenanceMargin;
    }

    function setBaseInitialMargin(MarketTypes.PerpMarketCfg storage _perpMarketCfg, uint32 _baseInitialMargin)
        internal
    {
        _perpMarketCfg.baseInitialMargin = _baseInitialMargin;
    }

    function setLiquidationFeeMax(MarketTypes.PerpMarketCfg storage _perpMarketCfg, uint256 _liquidationFeeMax)
        internal
    {
        _perpMarketCfg.liquidationFeeMax = _liquidationFeeMax;
    }

    function setMarkPrice(MarketTypes.PerpMarketCfg storage _perpMarketCfg, uint256 _markPrice) internal {
        _perpMarketCfg.markPrice = _markPrice;
    }

    function setIndexPriceOrderly(MarketTypes.PerpMarketCfg storage _perpMarketCfg, uint256 _indexPriceOrderly)
        internal
    {
        _perpMarketCfg.indexPriceOrderly = _indexPriceOrderly;
    }

    function setSumUnitaryFundings(MarketTypes.PerpMarketCfg storage _perpMarketCfg, int256 _sumUnitaryFundings)
        internal
    {
        _perpMarketCfg.sumUnitaryFundings = _sumUnitaryFundings;
    }

    function setLastMarkPriceUpdated(MarketTypes.PerpMarketCfg storage _perpMarketCfg, uint64 _lastMarkPriceUpdated)
        internal
    {
        _perpMarketCfg.lastMarkPriceUpdated = _lastMarkPriceUpdated;
    }

    function setLastFundingUpdated(MarketTypes.PerpMarketCfg storage _perpMarketCfg, uint64 _lastFundingUpdated)
        internal
    {
        _perpMarketCfg.lastFundingUpdated = _lastFundingUpdated;
    }
}

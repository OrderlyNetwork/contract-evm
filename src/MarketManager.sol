// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./interface/IMarketManager.sol";
import "./library/typesHelper/MarketTypeHelper.sol";
import "./LedgerComponent.sol";

contract MarketManager is IMarketManager, LedgerComponent {
    using MarketTypeHelper for MarketTypes.PerpMarketCfg;

    // pairSymbol => PerpMarketCfg
    mapping(bytes32 => MarketTypes.PerpMarketCfg) public perpMarketCfg;

    function setPerpMarketCfg(bytes32 _pairSymbol, MarketTypes.PerpMarketCfg memory _perpMarketCfg)
        external
        override
        onlyLedger
    {
        perpMarketCfg[_pairSymbol] = _perpMarketCfg;
    }

    function getPerpMarketCfg(bytes32 _pairSymbol) external view override returns (MarketTypes.PerpMarketCfg memory) {
        return perpMarketCfg[_pairSymbol];
    }

    function setBaseMaintenanceMargin(bytes32 _pairSymbol, uint32 _baseMaintenanceMargin)
        external
        override
        onlyLedger
    {
        perpMarketCfg[_pairSymbol].setBaseMaintenanceMargin(_baseMaintenanceMargin);
    }

    function setBaseInitialMargin(bytes32 _pairSymbol, uint32 _baseInitialMargin) external override onlyLedger {
        perpMarketCfg[_pairSymbol].setBaseInitialMargin(_baseInitialMargin);
    }

    function setLiquidationFeeMax(bytes32 _pairSymbol, uint256 _liquidationFeeMax) external override onlyLedger {
        perpMarketCfg[_pairSymbol].setLiquidationFeeMax(_liquidationFeeMax);
    }

    function setMarkPrice(bytes32 _pairSymbol, uint256 _markPrice) external override onlyLedger {
        perpMarketCfg[_pairSymbol].setMarkPrice(_markPrice);
    }

    function setIndexPriceOrderly(bytes32 _pairSymbol, uint256 _indexPriceOrderly) external override onlyLedger {
        perpMarketCfg[_pairSymbol].setIndexPriceOrderly(_indexPriceOrderly);
    }

    function setSumUnitaryFundings(bytes32 _pairSymbol, int256 _sumUnitaryFundings) external override onlyLedger {
        perpMarketCfg[_pairSymbol].setSumUnitaryFundings(_sumUnitaryFundings);
    }

    function setLastMarkPriceUpdated(bytes32 _pairSymbol, uint64 _lastMarkPriceUpdated) external override onlyLedger {
        perpMarketCfg[_pairSymbol].setLastMarkPriceUpdated(_lastMarkPriceUpdated);
    }

    function setLastFundingUpdated(bytes32 _pairSymbol, uint64 _lastFundingUpdated) external override onlyLedger {
        perpMarketCfg[_pairSymbol].setLastFundingUpdated(_lastFundingUpdated);
    }
}

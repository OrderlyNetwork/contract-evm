// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./interface/IMarketManager.sol";
import "./library/typesHelper/MarketTypeHelper.sol";
import "./LedgerComponent.sol";

contract MarketManager is IMarketManager, LedgerComponent {
    using MarketTypeHelper for MarketTypes.PerpMarketCfg;

    // pairSymbol => PerpMarketCfg
    mapping(bytes32 => MarketTypes.PerpMarketCfg) public perpMarketCfg;

    constructor() {
        _disableInitializers();
    }

    function initialize() public override initializer {
        __Ownable_init();
    }

    function updateMarketUpload(MarketTypes.UploadPerpPrice calldata data) external onlyLedger {
        uint256 length = data.perpPrices.length;
        for (uint256 i = 0; i < length; i++) {
            MarketTypes.PerpPrice calldata perpPrice = data.perpPrices[i];
            MarketTypes.PerpMarketCfg storage cfg = perpMarketCfg[perpPrice.symbolHash];
            cfg.setIndexPriceOrderly(perpPrice.indexPrice);
            cfg.setMarkPrice(perpPrice.markPrice);
            cfg.setLastMarkPriceUpdated(block.timestamp);
        }
        emit MarketData(data.maxTimestamp);
    }

    function updateMarketUpload(MarketTypes.UploadSumUnitaryFundings calldata data) external onlyLedger {
        uint256 length = data.sumUnitaryFundings.length;
        for (uint256 i = 0; i < length; i++) {
            MarketTypes.SumUnitaryFunding calldata sumUnitaryFunding = data.sumUnitaryFundings[i];
            MarketTypes.PerpMarketCfg storage cfg = perpMarketCfg[sumUnitaryFunding.symbolHash];
            cfg.setSumUnitaryFundings(sumUnitaryFunding.sumUnitaryFunding);
            cfg.setLastFundingUpdated(block.timestamp);
        }
        emit FundingData(data.maxTimestamp);
    }

    function setPerpMarketCfg(bytes32 _symbolHash, MarketTypes.PerpMarketCfg memory _perpMarketCfg)
        external
        override
        onlyLedger
    {
        perpMarketCfg[_symbolHash] = _perpMarketCfg;
    }

    function getPerpMarketCfg(bytes32 _pairSymbol) public view override returns (MarketTypes.PerpMarketCfg memory) {
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

    function setLiquidationFeeMax(bytes32 _pairSymbol, uint128 _liquidationFeeMax) external override onlyLedger {
        perpMarketCfg[_pairSymbol].setLiquidationFeeMax(_liquidationFeeMax);
    }

    function setMarkPrice(bytes32 _pairSymbol, uint128 _markPrice) external override onlyLedger {
        perpMarketCfg[_pairSymbol].setMarkPrice(_markPrice);
    }

    function setIndexPriceOrderly(bytes32 _pairSymbol, uint128 _indexPriceOrderly) external override onlyLedger {
        perpMarketCfg[_pairSymbol].setIndexPriceOrderly(_indexPriceOrderly);
    }

    function setSumUnitaryFundings(bytes32 _pairSymbol, int128 _sumUnitaryFundings) external override onlyLedger {
        perpMarketCfg[_pairSymbol].setSumUnitaryFundings(_sumUnitaryFundings);
    }

    function setLastMarkPriceUpdated(bytes32 _pairSymbol, uint64 _lastMarkPriceUpdated) external override onlyLedger {
        perpMarketCfg[_pairSymbol].setLastMarkPriceUpdated(_lastMarkPriceUpdated);
    }

    function setLastFundingUpdated(bytes32 _pairSymbol, uint64 _lastFundingUpdated) external override onlyLedger {
        perpMarketCfg[_pairSymbol].setLastFundingUpdated(_lastFundingUpdated);
    }

    // every time call `upgradeAndCall` will call this function, to do some data migrate or value init
    function upgradeInit() external {}
}

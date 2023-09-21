// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./interface/IMarketManager.sol";
import "./library/typesHelper/MarketTypeHelper.sol";
import "./LedgerComponent.sol";
import "./OperatorManagerComponent.sol";

/// @title A component of Ledger, saves market data
/// @author Orderly_Rubick
/// @notice MarketManager saves perpMarketCfg
contract MarketManager is IMarketManager, LedgerComponent, OperatorManagerComponent {
    using MarketTypeHelper for MarketTypes.PerpMarketCfg;

    // pairSymbol => PerpMarketCfg
    mapping(bytes32 => MarketTypes.PerpMarketCfg) public perpMarketCfg;

    constructor() {
        _disableInitializers();
    }

    function initialize() external override initializer {
        __Ownable_init();
    }

    function updateMarketUpload(MarketTypes.UploadPerpPrice calldata data) external onlyOperatorManager {
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

    function updateMarketUpload(MarketTypes.UploadSumUnitaryFundings calldata data) external onlyOperatorManager {
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
        onlyOwner
    {
        perpMarketCfg[_symbolHash] = _perpMarketCfg;
    }

    function getPerpMarketCfg(bytes32 _pairSymbol) public view override returns (MarketTypes.PerpMarketCfg memory) {
        return perpMarketCfg[_pairSymbol];
    }

    function setLastMarkPriceUpdated(bytes32 _pairSymbol, uint64 _lastMarkPriceUpdated) external override onlyOwner {
        perpMarketCfg[_pairSymbol].setLastMarkPriceUpdated(_lastMarkPriceUpdated);
    }

    function setLastFundingUpdated(bytes32 _pairSymbol, uint64 _lastFundingUpdated) external override onlyLedger {
        perpMarketCfg[_pairSymbol].setLastFundingUpdated(_lastFundingUpdated);
    }
}

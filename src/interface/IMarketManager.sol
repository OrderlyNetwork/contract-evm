// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types/MarketTypes.sol";
import "./ILedgerComponent.sol";

interface IMarketManager is ILedgerComponent {
    event MarketData(uint64 maxTimestamp);
    event FundingData(uint64 maxTimestamp);

    function initialize() external;

    // update functions
    function updateMarketUpload(MarketTypes.UploadPerpPrice calldata data) external;
    function updateMarketUpload(MarketTypes.UploadSumUnitaryFundings calldata data) external;

    function setPerpMarketCfg(bytes32 _pairSymbol, MarketTypes.PerpMarketCfg memory _perpMarketCfg) external;
    function getPerpMarketCfg(bytes32 _pairSymbol) external view returns (MarketTypes.PerpMarketCfg memory);

    // set functions
    function setBaseMaintenanceMargin(bytes32 _pairSymbol, uint32 _baseMaintenanceMargin) external;
    function setBaseInitialMargin(bytes32 _pairSymbol, uint32 _baseInitialMargin) external;
    function setLiquidationFeeMax(bytes32 _pairSymbol, uint128 _liquidationFeeMax) external;
    function setMarkPrice(bytes32 _pairSymbol, uint128 _markPrice) external;
    function setIndexPriceOrderly(bytes32 _pairSymbol, uint128 _indexPriceOrderly) external;
    function setSumUnitaryFundings(bytes32 _pairSymbol, int128 _sumUnitaryFundings) external;
    function setLastMarkPriceUpdated(bytes32 _pairSymbol, uint64 _lastMarkPriceUpdated) external;
    function setLastFundingUpdated(bytes32 _pairSymbol, uint64 _lastFundingUpdated) external;
}

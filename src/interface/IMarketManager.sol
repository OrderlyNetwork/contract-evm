// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types/MarketTypes.sol";
import "./ILedgerComponent.sol";

interface IMarketManager is ILedgerComponent {
    function setPerpMarketCfg(bytes32 _pairSymbol, MarketTypes.PerpMarketCfg memory _perpMarketCfg) external;
    function getPerpMarketCfg(bytes32 _pairSymbol) external view returns (MarketTypes.PerpMarketCfg memory);

    // set functions
    function setBaseMaintenanceMargin(bytes32 _pairSymbol, uint32 _baseMaintenanceMargin) external;
    function setBaseInitialMargin(bytes32 _pairSymbol, uint32 _baseInitialMargin) external;
    function setLiquidationFeeMax(bytes32 _pairSymbol, uint256 _liquidationFeeMax) external;
    function setMarkPrice(bytes32 _pairSymbol, uint256 _markPrice) external;
    function setIndexPriceOrderly(bytes32 _pairSymbol, uint256 _indexPriceOrderly) external;
    function setSumUnitaryFundings(bytes32 _pairSymbol, int256 _sumUnitaryFundings) external;
    function setLastMarkPriceUpdated(bytes32 _pairSymbol, uint64 _lastMarkPriceUpdated) external;
    function setLastFundingUpdated(bytes32 _pairSymbol, uint64 _lastFundingUpdated) external;
}

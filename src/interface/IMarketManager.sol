// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types/MarketTypes.sol";
import "./ILedgerComponent.sol";
import "./IOperatorManagerComponent.sol";

interface IMarketManager is ILedgerComponent, IOperatorManagerComponent {
    event MarketData(uint64 maxTimestamp);
    event FundingData(uint64 maxTimestamp);

    function initialize() external;

    // update functions
    function updateMarketUpload(MarketTypes.UploadPerpPrice calldata data) external;
    function updateMarketUpload(MarketTypes.UploadSumUnitaryFundings calldata data) external;

    function setPerpMarketCfg(bytes32 _pairSymbol, MarketTypes.PerpMarketCfg memory _perpMarketCfg) external;
    function getPerpMarketCfg(bytes32 _pairSymbol) external view returns (MarketTypes.PerpMarketCfg memory);

    // set functions
    function setLastMarkPriceUpdated(bytes32 _pairSymbol, uint64 _lastMarkPriceUpdated) external;
    function setLastFundingUpdated(bytes32 _pairSymbol, uint64 _lastFundingUpdated) external;
}

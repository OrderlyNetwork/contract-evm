// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types/AccountTypes.sol";
import "../library/types/PerpTypes.sol";
import "../library/types/EventTypes.sol";
import "../library/types/MarketTypes.sol";
import "../library/types/RebalanceTypes.sol";
import "./error/IError.sol";
import "./IOperatorManagerEvent.sol";

interface IOperatorManagerImplA is IError, IOperatorManagerEvent {
    // operator call futures trade upload
    function futuresTradeUpload(PerpTypes.FuturesTradeUploadData calldata data) external;
    // operator call event upload
    function eventUpload(EventTypes.EventUpload calldata data) external;
    // operator call perp market info
    function perpPriceUpload(MarketTypes.UploadPerpPrice calldata data) external;
    function sumUnitaryFundingsUpload(MarketTypes.UploadSumUnitaryFundings calldata data) external;
    // operator call rebalance mint
    function rebalanceBurnUpload(RebalanceTypes.RebalanceBurnUploadData calldata) external;
    function rebalanceMintUpload(RebalanceTypes.RebalanceMintUploadData calldata) external;
    // operator call ping
    function operatorPing() external;
}

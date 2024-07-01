// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types/AccountTypes.sol";
import "../library/types/PerpTypes.sol";
import "../library/types/EventTypes.sol";
import "../library/types/MarketTypes.sol";
import "../library/types/RebalanceTypes.sol";
import "./error/IError.sol";
import "./ILedgerEvent.sol";

interface ILedgerImplB is IError, ILedgerEvent {
    // Functions called by operator manager to executre actions
    function executeProcessValidatedFuturesBatch(PerpTypes.FuturesTradeUpload[] calldata trades) external;
}

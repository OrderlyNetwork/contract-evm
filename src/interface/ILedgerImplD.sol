// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types/AccountTypes.sol";
import "../library/types/PerpTypes.sol";
import "../library/types/EventTypes.sol";
import "../library/types/MarketTypes.sol";
import "../library/types/RebalanceTypes.sol";
import "./error/IError.sol";
import "./ILedgerEvent.sol";

interface ILedgerImplD is IError, ILedgerEvent {
    function executeWithdraw2Contract(EventTypes.Withdraw2Contract calldata data, uint64 eventId) external;
    function executeSwapResultUpload(EventTypes.SwapResult calldata swapResultUpload, uint64 eventId) external;
    function executeWithdraw2ContractV2(EventTypes.Withdraw2ContractV2 calldata data, uint64 eventId) external;
}

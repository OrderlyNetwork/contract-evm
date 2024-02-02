// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types/AccountTypes.sol";
import "../library/types/PerpTypes.sol";
import "../library/types/EventTypes.sol";
import "../library/types/MarketTypes.sol";
import "../library/types/RebalanceTypes.sol";
import "./error/IError.sol";
import "./ILedgerEvent.sol";

interface ILedgerImplA is IError, ILedgerEvent {
    function initialize() external;

    // Functions called by cross chain manager on Ledger side
    function accountDeposit(AccountTypes.AccountDeposit calldata data) external;
    function accountWithDrawFinish(AccountTypes.AccountWithdraw calldata withdraw) external;

    // Functions called by operator manager to executre actions
    function executeProcessValidatedFutures(PerpTypes.FuturesTradeUpload calldata trade) external;
    function executeWithdrawAction(EventTypes.WithdrawData calldata withdraw, uint64 eventId) external;
    function executeSettlement(EventTypes.Settlement calldata ledger, uint64 eventId) external;
    function executeLiquidation(EventTypes.Liquidation calldata liquidation, uint64 eventId) external;
    function executeAdl(EventTypes.Adl calldata adl, uint64 eventId) external;
    function executeFeeDistribution(EventTypes.FeeDistribution calldata feeDistribution, uint64 eventId) external;
    function executeDelegateSigner(EventTypes.DelegateSigner calldata delegateSigner, uint64 eventId) external;
    function executeDelegateWithdrawAction(EventTypes.WithdrawData calldata withdraw, uint64 eventId) external;
}

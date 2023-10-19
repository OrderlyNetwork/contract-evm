// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types/AccountTypes.sol";
import "../library/types/PerpTypes.sol";
import "../library/types/EventTypes.sol";
import "../library/types/MarketTypes.sol";
import "./ILedgerError.sol";
import "./ILedgerEvent.sol";

// Defines the error, event and ABI.
// Data should be stored in LedgerDataLayout, NOT in this contract.
interface ILedger is ILedgerError, ILedgerEvent {
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

    // view call
    function getFrozenWithdrawNonce(bytes32 accountId, uint64 withdrawNonce, bytes32 tokenHash)
        external
        view
        returns (uint128);
    // omni view call
    function batchGetUserLedger(bytes32[] calldata accountIds, bytes32[] memory tokens, bytes32[] memory symbols)
        external
        view
        returns (AccountTypes.AccountSnapshot[] memory);
    function batchGetUserLedger(bytes32[] calldata accountIds)
        external
        view
        returns (AccountTypes.AccountSnapshot[] memory);

    // admin call
    function setOperatorManagerAddress(address _operatorManagerAddress) external;
    function setCrossChainManager(address _crossChainManagerAddress) external;
    function setVaultManager(address _vaultManagerAddress) external;
    function setMarketManager(address _marketManagerAddress) external;
    function setFeeManager(address _feeManagerAddress) external;
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

interface ILedgerError {
    error OnlyOperatorCanCall();
    error OnlyCrossChainManagerCanCall();
    error TotalSettleAmountNotMatch(int128 amount);
    error BalanceNotEnough(uint128 balance, int128 amount);
    error InsuranceTransferToSelf();
    error InsuranceTransferAmountInvalid(uint128 balance, uint128 insuranceTransferAmount, int128 settledAmount);
    error UserPerpPositionQtyZero(bytes32 accountId, bytes32 symbolHash);
    error InsurancePositionQtyInvalid(int128 adlPositionQtyTransfer, int128 userPositionQty);
    error AccountIdInvalid();
    error TokenNotAllowed(bytes32 tokenHash, uint256 chainId);
    error BrokerNotAllowed();
    error SymbolNotAllowed();
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../types/AccountTypes.sol";
import "../typesHelper/SafeCastHelper.sol";

/// @title AccountTypeHelper library
/// @author Orderly_Rubick
library AccountTypeHelper {
    using SafeCastHelper for uint128;

    error FrozenBalanceInconsistent(); // should never happen

    // ====================
    // part1: methods for get meta data
    // ====================

    /// @notice get balance
    function getBalance(AccountTypes.Account storage account, bytes32 tokenHash) internal view returns (int128) {
        return account.balances[tokenHash];
    }

    /// @notice get brokerHash
    function getBrokerHash(AccountTypes.Account storage account) internal view returns (bytes32) {
        return account.brokerHash;
    }

    /// @notice get last engine event id
    function getLastEngineEventId(AccountTypes.Account storage account) internal view returns (uint64) {
        return account.lastEngineEventId;
    }

    // ====================
    // part2: methods for balance | frozen balance
    // ====================

    /// @notice add balance
    function addBalance(AccountTypes.Account storage account, bytes32 tokenHash, uint128 amount) internal {
        account.balances[tokenHash] += amount.toInt128();
    }

    /// @notice sub balance
    function subBalance(AccountTypes.Account storage account, bytes32 tokenHash, uint128 amount) internal {
        account.balances[tokenHash] -= amount.toInt128();
    }

    /// @notice apply delta to balance with a given tokenHash
    function applyDelta(AccountTypes.Account storage account, bytes32 tokenHash, int128 delta) internal {
        account.balances[tokenHash] += delta;
    }

    /// @notice frozen balance with a given withdrawNonce & amount
    function frozenBalance(
        AccountTypes.Account storage account,
        uint64 withdrawNonce,
        bytes32 tokenHash,
        uint128 amount
    ) internal {
        account.balances[tokenHash] -= amount.toInt128();
        account.totalFrozenBalances[tokenHash] += amount;
        account.frozenBalances[withdrawNonce][tokenHash] = amount;
        account.lastWithdrawNonce = withdrawNonce;
    }

    /// @notice revert frozen balance
    function unfrozenBalance(
        AccountTypes.Account storage account,
        uint64 withdrawNonce,
        bytes32 tokenHash,
        uint128 amount
    ) internal {
        account.balances[tokenHash] += amount.toInt128();
        account.totalFrozenBalances[tokenHash] -= amount;
        account.frozenBalances[withdrawNonce][tokenHash] -= amount;
        if (account.frozenBalances[withdrawNonce][tokenHash] != 0) revert FrozenBalanceInconsistent();
    }

    /// @notice transfer frozen balance out
    function finishFrozenBalance(
        AccountTypes.Account storage account,
        uint64 withdrawNonce,
        bytes32 tokenHash,
        uint128 amount
    ) internal {
        account.totalFrozenBalances[tokenHash] -= amount;
        account.frozenBalances[withdrawNonce][tokenHash] -= amount;
        if (account.frozenBalances[withdrawNonce][tokenHash] != 0) revert FrozenBalanceInconsistent();
    }

    function getFrozenTotalBalance(AccountTypes.Account storage account, bytes32 tokenHash)
        internal
        view
        returns (uint128)
    {
        return account.totalFrozenBalances[tokenHash];
    }

    function getFrozenWithdrawNonceBalance(
        AccountTypes.Account storage account,
        uint64 withdrawNonce,
        bytes32 tokenHash
    ) internal view returns (uint128) {
        return account.frozenBalances[withdrawNonce][tokenHash];
    }
}

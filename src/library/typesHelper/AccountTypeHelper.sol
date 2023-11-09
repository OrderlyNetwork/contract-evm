// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../types/AccountTypes.sol";

/// @title AccountTypeHelper library
/// @author Orderly_Rubick
library AccountTypeHelper {
    // ====================
    // part1: methods for get meta data
    // ====================

    /// @notice get balance
    function getBalance(AccountTypes.Account storage account, bytes32 tokenHash) internal view returns (uint128) {
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
        account.balances[tokenHash] += amount;
    }

    /// @notice sub balance
    function subBalance(AccountTypes.Account storage account, bytes32 tokenHash, uint128 amount) internal {
        account.balances[tokenHash] -= amount;
    }

    /// @notice frozen balance with a given withdrawNonce & amount
    function frozenBalance(
        AccountTypes.Account storage account,
        uint64 withdrawNonce,
        bytes32 tokenHash,
        uint128 amount
    ) internal {
        account.balances[tokenHash] -= amount;
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
        account.balances[tokenHash] += amount;
        account.totalFrozenBalances[tokenHash] -= amount;
        account.frozenBalances[withdrawNonce][tokenHash] = 0;
    }

    /// @notice transfer frozen balance out
    function finishFrozenBalance(
        AccountTypes.Account storage account,
        uint64 withdrawNonce,
        bytes32 tokenHash,
        uint128 amount
    ) internal {
        account.totalFrozenBalances[tokenHash] -= amount;
        account.frozenBalances[withdrawNonce][tokenHash] = 0;
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

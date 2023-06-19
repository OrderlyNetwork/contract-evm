// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../types/AccountTypes.sol";

library AccountTypeHelper {
    // ====================
    // part1: methods for get meta data
    // ====================

    // get balance
    function getBalance(AccountTypes.Account storage account, bytes32 tokenHash) internal view returns (uint256) {
        return account.balances[tokenHash];
    }

    // get brokerHash
    function getBrokerHash(AccountTypes.Account storage account) internal view returns (bytes32) {
        return account.brokerHash;
    }

    // get last cefi event id
    function getLastCefiEventId(AccountTypes.Account storage account) internal view returns (uint64) {
        return account.lastCefiEventId;
    }

    // ====================
    // part2: methods for balance | frozen balance
    // ====================

    // add balance
    function addBalance(AccountTypes.Account storage account, bytes32 tokenHash, uint256 amount) internal {
        account.balances[tokenHash] += amount;
    }

    // frozen balance with a given withdrawNonce & amount
    function frozenBalance(
        AccountTypes.Account storage account,
        uint64 withdrawNonce,
        bytes32 tokenHash,
        uint256 amount
    ) internal {
        account.balances[tokenHash] -= amount;
        account.totalFrozenBalances[tokenHash] += amount;
        account.frozenBalances[withdrawNonce][tokenHash] = amount;
    }

    // revert frozen balance
    function unfrozenBalance(
        AccountTypes.Account storage account,
        uint64 withdrawNonce,
        bytes32 tokenHash,
        uint256 amount
    ) internal {
        account.balances[tokenHash] += amount;
        account.totalFrozenBalances[tokenHash] -= amount;
        account.frozenBalances[withdrawNonce][tokenHash] = 0;
    }

    // transfer frozen balance out
    function finishFrozenBalance(
        AccountTypes.Account storage account,
        uint64 withdrawNonce,
        bytes32 tokenHash,
        uint256 amount
    ) internal {
        account.totalFrozenBalances[tokenHash] -= amount;
        account.frozenBalances[withdrawNonce][tokenHash] = 0;
    }

    function getFrozenTotalBalance(AccountTypes.Account storage account, bytes32 tokenHash)
        internal
        view
        returns (uint256)
    {
        return account.totalFrozenBalances[tokenHash];
    }

    function getFrozenWithdrawNonceBalance(
        AccountTypes.Account storage account,
        uint64 withdrawNonce,
        bytes32 tokenHash
    ) internal view returns (uint256) {
        return account.frozenBalances[withdrawNonce][tokenHash];
    }
}

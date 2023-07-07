// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "../../src/Ledger.sol";

contract LedgerCheater is Ledger {
    using AccountTypeHelper for AccountTypes.Account;

    function cheatDeposit(bytes32 accountId, bytes32 tokenHash, uint128 tokenAmount, uint256 srcChainId) external {
        AccountTypes.Account storage account = userLedger[accountId];

        account.addBalance(tokenHash, tokenAmount);
        vaultManager.addBalance(tokenHash, srcChainId, tokenAmount);
        account.lastDepositEventId = _newGlobalDepositId();
    }

    function cheatSetUserPosition(bytes32 accountId, bytes32 symbolHash, AccountTypes.PerpPosition memory position)
        external
    {
        AccountTypes.Account storage account = userLedger[accountId];
        account.perpPositions[symbolHash] = position;
    }
}

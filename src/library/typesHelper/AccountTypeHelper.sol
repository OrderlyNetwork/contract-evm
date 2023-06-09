// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../types/AccountTypes.sol";

library AccountTypeHelper {
    int256 constant FUNDING_MOVE_RIGHT_PRECISIONS = 100000000000000000;

    // frozen balance with a given withdrawNonce & amount
    function frozenBalance(AccountTypes.Account storage account, uint64 withdrawNonce, bytes32 tokenHash, uint256 amount) internal {
        account.balances[tokenHash] -= amount;
        account.totalFrozenBalances[tokenHash] += amount;
        account.frozenBalances[withdrawNonce][tokenHash] = amount;
    }

    // revert frozen balance
    function unfrozenBalance(AccountTypes.Account storage account, uint64 withdrawNonce, bytes32 tokenHash, uint256 amount) internal {
        account.balances[tokenHash] += amount;
        account.totalFrozenBalances[tokenHash] -= amount;
        account.frozenBalances[withdrawNonce][tokenHash] = 0;
    }

    // transfer frozen balance out
    function finishFrozenBalance(AccountTypes.Account storage account, uint64 withdrawNonce, bytes32 tokenHash, uint256 amount) internal {
        account.totalFrozenBalances[tokenHash] -= amount;
        account.frozenBalances[withdrawNonce][tokenHash] = 0;
    }

    function getFrozenTotalBalance(AccountTypes.Account storage account, bytes32 tokenHash) internal view returns(uint256) {
        return account.totalFrozenBalances[tokenHash];
    }

    function getFrozenWithdrawNonceBalance(AccountTypes.Account storage account, uint64 withdrawNonce, bytes32 tokenHash) internal view returns(uint256) {
        return account.frozenBalances[withdrawNonce][tokenHash];
    }

    // charge funding fee
    function chargeFundingFee(AccountTypes.PerpPosition storage position, int256 sumUnitaryFundings) internal {
        int256 accruedFeeUncoverted = position.positionQty * (sumUnitaryFundings - position.lastSumUnitaryFundings);
        int256 accruedFee = accruedFeeUncoverted / FUNDING_MOVE_RIGHT_PRECISIONS;
        int256 remainder = accruedFeeUncoverted - (accruedFee * FUNDING_MOVE_RIGHT_PRECISIONS);
        if (remainder > 0) {
            accruedFee += 1;
        }
        position.cost_position += accruedFee;
        position.lastSumUnitaryFundings = sumUnitaryFundings;
    }
}
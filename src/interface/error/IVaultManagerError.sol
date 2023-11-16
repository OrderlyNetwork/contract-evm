// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

interface IVaultManagerError {
    error EnumerableSetError();
    error RebalanceIdNotMatch(uint64 givenId, uint64 wantId); // the given rebalanceId not match the latest rebalanceId
    error RebalanceStillPending(); // the rebalance is still pending, so no need to upload again
    error RebalanceAlreadySucc(); // the rebalance is already succ, so no need to upload again
    error RebalanceMintUnexpected(); // the rebalance burn state or something is wrong, so the rebalance mint is unexpected. Should never happen.
}

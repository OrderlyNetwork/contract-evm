// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// Importing types
import "../library/types/EventTypes.sol";

/// @title ILedgerCrossChainManagerV2 Interface
/// @notice Interface for managing cross-chain activities related to the ledger.
interface ILedgerCrossChainManagerV2 {
    /// @notice Approves a cross-chain withdrawal from the ledger to the vault.
    /// @param data Struct containing withdrawal data.
    function withdraw(EventTypes.WithdrawDataSol memory data) external;
}

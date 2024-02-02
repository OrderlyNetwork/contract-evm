// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/typesHelper/AccountTypeHelper.sol";
import "../library/types/RebalanceTypes.sol";
import "../interface/IVaultManager.sol";
import "../interface/IMarketManager.sol";
import "../interface/IFeeManager.sol";

/// @title Ledger contract data layout
/// @author Orderly_Rubick
/// @notice DataLayout for Ledger contract, align with 50 slots
contract LedgerDataLayout {
    // A mapping from accountId to Orderly Account
    mapping(bytes32 => AccountTypes.Account) internal userLedger;
    // The OperatorManager contract address
    address public operatorManagerAddress;
    // The crossChainManagerAddress contract address
    address public crossChainManagerAddress;
    // The interface for VaultManager contract
    IVaultManager public vaultManager;
    // The interface for MarketManager contract
    IMarketManager public marketManager;
    // An increasing global event Id, for event trade upload
    uint64 public globalEventId;
    // The interface for FeeManager contract
    IFeeManager public feeManager;
    // An incresing global deposit Id for cross chain deposit
    uint64 public globalDepositId;
    // A mapping from contract accountId to its delegate signer
    mapping(bytes32 => AccountTypes.AccountDelegateSigner) public contractSigner;

    // The storage gap to prevent overwriting by proxy
    uint256[43] private __gap;
}

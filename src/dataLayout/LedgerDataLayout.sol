// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/typesHelper/AccountTypeHelper.sol";
import "../library/types/RebalanceTypes.sol";
import "../library/types/EventTypes.sol";
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
    // crossChainManagerV2Address, for lzv2
    address public crossChainManagerV2Address;
    // Id(accountId or spId) => Ceffu Prime Wallet
    mapping(bytes32 => address) public idToPrimeWallet;

    /// @dev Mapping from accountId => tokenHash => escrow balance
    /// @notice Tracks amounts that have been credited but not yet finalized
    mapping(bytes32 => mapping(bytes32 => uint128)) internal escrowBalances;

    /// @dev Mapping from transferId => InternalTransferTrack
    /// @notice Tracks the state of each internal transfer
    mapping(uint256 => EventTypes.InternalTransferTrack) internal transfers;

    mapping(address vault => bool) public isValidVault;

    // Id(accountId or spId) => Ceffu Prime Wallet on Solana
    mapping(bytes32 => bytes32) public idToSolanaPrimeWallet;

    // The storage gap to prevent overwriting by proxy
    uint256[37] private __gap;
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "../library/typesHelper/AccountTypeHelper.sol";
import "../interface/IVaultManager.sol";
import "../interface/ILedgerCrossChainManager.sol";
import "../interface/IMarketManager.sol";
import "../interface/IFeeManager.sol";

contract LedgerDataLayout {
    // A mapping from accountId to Orderly Account
    mapping(bytes32 => AccountTypes.Account) internal userLedger;
    // The OperatorManager contract address
    address public operatorManagerAddress;
    // The crossChainManagerAddress contract address
    address public crossChainManagerAddress;
    // The interface for VaultManager contract
    IVaultManager public vaultManager;
    // operatorTradesBatchId
    uint64 public operatorTradesBatchId;
    // The interface for MarketManager contract
    IMarketManager public marketManager;
    // An increasing global event Id, for event trade upload
    uint64 public globalEventId;
    // The interface for FeeManager contract
    IFeeManager public feeManager;
    // An incresing global deposit Id for cross chain deposit
    uint64 public globalDepositId;

    // The storage gap to prevent overwriting by proxy
    uint256[44] private __gap;
}

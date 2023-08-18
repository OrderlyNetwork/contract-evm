// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "../library/typesHelper/AccountTypeHelper.sol";
import "../interface/IVaultManager.sol";
import "../interface/ILedgerCrossChainManager.sol";
import "../interface/IMarketManager.sol";
import "../interface/IFeeManager.sol";

contract LedgerDataLayout {
    // userLedger accountId -> Account
    mapping(bytes32 => AccountTypes.Account) internal userLedger;
    // OperatorManager contract address
    address public operatorManagerAddress;
    // crossChainManagerAddress contract address
    address public crossChainManagerAddress;
    // VaultManager contract
    IVaultManager public vaultManager;
    // operatorTradesBatchId
    uint64 public operatorTradesBatchId;
    // MarketManager contract
    IMarketManager public marketManager;
    // globalEventId, for event trade upload
    uint64 public globalEventId;
    // FeeManager contract
    IFeeManager public feeManager;
    // globalDepositId
    uint64 public globalDepositId;

    // gap
    uint256[44] private __gap;
}

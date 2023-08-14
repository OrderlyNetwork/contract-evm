// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "../library/typesHelper/AccountTypeHelper.sol";
import "../interface/IVaultManager.sol";
import "../interface/ILedgerCrossChainManager.sol";
import "../interface/IMarketManager.sol";
import "../interface/IFeeManager.sol";

contract LedgerDataLayout {
    // OperatorManager contract address
    address public operatorManagerAddress;
    // crossChainManagerAddress contract address
    address public crossChainManagerAddress;
    // TODO @Rubick reorder to save slots
    // operatorTradesBatchId
    uint64 public operatorTradesBatchId;
    // globalEventId, for event trade upload
    uint64 public globalEventId;
    // globalDepositId
    uint64 public globalDepositId;
    // @Rubick refactor order when next deployment
    // userLedger accountId -> Account
    mapping(bytes32 => AccountTypes.Account) internal userLedger;

    // VaultManager contract
    IVaultManager public vaultManager;
    // @Rubick remove this when next deployment
    // CrossChainManager contract
    ILedgerCrossChainManager public _deprecated;
    // MarketManager contract
    IMarketManager public marketManager;
    // FeeManager contract
    IFeeManager public feeManager;

    // gap
    uint256[42] private __gap;
}

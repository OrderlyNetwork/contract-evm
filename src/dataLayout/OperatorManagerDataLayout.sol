// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "../interface/ILedger.sol";
import "../interface/IMarketManager.sol";

contract OperatorManagerDataLayout {
    // operator address
    address public operatorAddress;
    // ledger Interface
    ILedger public ledger;
    // futuresUploadBatchId
    uint64 public futuresUploadBatchId;
    // market manager Interface
    IMarketManager public marketManager;
    // eventUploadBatchId
    uint64 public eventUploadBatchId;

    // last operator interaction timestamp
    uint256 public lastOperatorInteraction;

    // cefi sign address
    address public cefiSpotTradeUploadAddress;
    address public cefiPerpTradeUploadAddress;
    address public cefiEventUploadAddress;
    address public cefiMarketUploadAddress;

    // gap
    uint256[42] private __gap;
}

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

    // TODO @Rubick reorder to save slots
    // ids
    // futuresUploadBatchId
    uint64 public futuresUploadBatchId;
    // eventUploadBatchId
    uint64 public eventUploadBatchId;
    // last operator interaction timestamp
    uint256 public lastOperatorInteraction;
    // @depreacted @Rubick
    address public _depreacted;
    // cefi sign address
    address public cefiSpotTradeUploadAddress;
    address public cefiPerpTradeUploadAddress;
    address public cefiEventUploadAddress;
    address public cefiMarketUploadAddress;
    // TODO @Rubick reoerder this
    // market manager Interface
    IMarketManager public marketManager;

    // gap
    uint256[40] private __gap;
}

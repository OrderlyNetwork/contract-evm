// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "../interface/ILedger.sol";
import "../interface/IMarketManager.sol";

contract OperatorManagerDataLayout {
    // An EOA operator address
    address public operatorAddress;
    // The ledger Interface
    ILedger public ledger;
    // An increasing Id for the batch of perpetual futures trading upload from Operator
    uint64 public futuresUploadBatchId;
    // The market manager Interface
    IMarketManager public marketManager;
    // An increasing Id for the event upload from Operator
    uint64 public eventUploadBatchId;

    // The last operator interaction timestamp
    uint256 public lastOperatorInteraction;

    // The signature addresses of CeFi
    address public cefiSpotTradeUploadAddress;
    address public cefiPerpTradeUploadAddress;
    address public cefiEventUploadAddress;
    address public cefiMarketUploadAddress;

    // The storage gap to prevent overwriting by proxy
    uint256[42] private __gap;
}

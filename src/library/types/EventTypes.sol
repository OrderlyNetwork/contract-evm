// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

library EventTypes {
    // EventUpload
    struct EventUpload {
        EventUploadData[] events;
        bytes32 r;
        bytes32 s;
        uint8 v;
        uint8 count;
        uint64 batchId;
    }

    struct EventUploadData {
        bytes32 bizTypeHash; // keccak256(bizType)
        uint64 eventId;
        bytes data;
    }

    // WithdrawData
    struct WithdrawData {
        uint256 tokenAmount;
        uint256 fee;
        uint256 chainId; // target withdraw chain
        bytes32 accountId;
        bytes32 r; // String to bytes32, big endian?
        bytes32 s;
        uint8 v;
        address sender;
        uint64 withdrawNonce;
        address receiver;
        uint64 timestamp;
        string brokerId; // only this field is string, others should be bytes32 hashedBrokerId
        string tokenSymbol; // only this field is string, others should be bytes32 hashedTokenSymbol
    }

    struct LedgerData {
        bytes32 accountId;
        int256 settledAmount;
        bytes32 settledAsset;
        uint256 insuranceTransferAmount;
        LedgerExecution[] ledgerExecutions;
    }

    struct LiquidationData {
        bytes32 accountId;
        int256 settledAmount;
        LiquidationTransfer[] liquidationTransfers;
        uint256 timestamp;
        bytes32 liquidatedAsset;
    }

    struct LiquidationTransfer {
        uint256 liquidationTransferId;
        bytes32 liquidatorAccountId;
        bytes32 listSymbol;
        int256 positionQtyTransfer;
        int256 costPositionTransfer;
        uint256 liquidatorFee;
        uint256 insuranceFee;
        uint256 markPrice;
        int256 sumUnitaryFundings;
        uint256 liquidationFee;
    }

    struct LedgerExecution {
        bytes32 symbol;
        int256 sumUnitaryFundings;
        uint256 markPrice;
        int256 settledAmount;
    }
}

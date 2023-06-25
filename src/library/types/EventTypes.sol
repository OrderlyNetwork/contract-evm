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
        uint128 tokenAmount;
        uint128 fee;
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
        bytes32 settledAsset;
        int128 settledAmount;
        uint128 insuranceTransferAmount;
        LedgerExecution[] ledgerExecutions;
    }

    struct LiquidationData {
        bytes32 accountId;
        int128 settledAmount;
        uint64 timestamp;
        bytes32 liquidatedAsset;
        LiquidationTransfer[] liquidationTransfers;
    }

    struct LiquidationTransfer {
        uint64 liquidationTransferId;
        bytes32 liquidatorAccountId;
        bytes32 listSymbol;
        int128 positionQtyTransfer;
        int128 costPositionTransfer;
        uint128 liquidatorFee;
        uint128 insuranceFee;
        uint128 markPrice;
        int128 sumUnitaryFundings;
        uint128 liquidationFee;
    }

    struct LedgerExecution {
        bytes32 symbol;
        int128 sumUnitaryFundings;
        uint128 markPrice;
        int128 settledAmount;
    }
}

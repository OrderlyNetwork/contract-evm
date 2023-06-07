// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

library EventTypes {
    // EventUpload
    struct EventUpload {
        uint256 batchId;
        uint256 count;
        EventUploadData[] events;
    }

    struct EventUploadData {
        uint256 eventId;
        uint256 bizId; // data type, WIP, 0 for `WithdrawData`
        bytes data;
    }

    // WithdrawData
    struct WithdrawData {
        bytes32 accountId;
        address sender;
        address receiver;
        string brokerId; // only this field is string, others should be bytes32 hashedBrokerId
        string tokenSymbol; // only this field is string, others should be bytes32 hashedTokenSymbol
        uint256 tokenAmount;
        uint256 fee;
        uint256 chainId; // target withdraw chain
        uint64 withdrawNonce; // withdraw nonce
        uint64 timestamp;
        uint8 v;
        bytes32 r;
        bytes32 s;
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

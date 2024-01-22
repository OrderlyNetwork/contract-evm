// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

/// @title EventTypes library
/// @author Orderly_Rubick
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
        uint8 bizType; // 1 - withdraw, 2 - settlement, 3 - adl, 4 - liquidation, 5 - fee distribution, 6 - delegate signer, 7 - delegate withdraw
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

    struct Settlement {
        bytes32 accountId;
        bytes32 settledAssetHash;
        bytes32 insuranceAccountId;
        int128 settledAmount;
        uint128 insuranceTransferAmount;
        uint64 timestamp;
        SettlementExecution[] settlementExecutions;
    }

    struct SettlementExecution {
        bytes32 symbolHash;
        uint128 markPrice;
        int128 sumUnitaryFundings;
        int128 settledAmount;
    }

    struct Adl {
        bytes32 accountId;
        bytes32 insuranceAccountId;
        bytes32 symbolHash;
        int128 positionQtyTransfer;
        int128 costPositionTransfer;
        uint128 adlPrice;
        int128 sumUnitaryFundings;
        uint64 timestamp;
    }

    struct Liquidation {
        bytes32 liquidatedAccountId;
        bytes32 insuranceAccountId;
        bytes32 liquidatedAssetHash;
        uint128 insuranceTransferAmount;
        uint64 timestamp;
        LiquidationTransfer[] liquidationTransfers;
    }

    struct LiquidationTransfer {
        bytes32 liquidatorAccountId;
        bytes32 symbolHash;
        int128 positionQtyTransfer;
        int128 costPositionTransfer;
        int128 liquidatorFee;
        int128 insuranceFee;
        int128 liquidationFee;
        uint128 markPrice;
        int128 sumUnitaryFundings;
        uint64 liquidationTransferId;
    }

    struct FeeDistribution {
        bytes32 fromAccountId;
        bytes32 toAccountId;
        uint128 amount;
        bytes32 tokenHash;
    }

    struct DelegateSigner {
        address delegateSigner;
        address delegateContract;
        bytes32 brokerHash;
        uint256 chainId;
    }
}

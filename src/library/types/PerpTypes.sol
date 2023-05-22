// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

library PrepTypes {
    // FuturesTradeUploadData
    struct FuturesTradeUploadData {
        uint256 batchId;
        uint256 count;
        FuturesTradeUpload[] trades;
    }

    struct FuturesTradeUpload {
        uint256 tradeId;
        uint256 matchId;
        bytes32 accountId;
        address addr;
        string symbol;
        bool side;
        uint256 tradeQty;
        // signature for validate signed by real user
        bytes signature;
    }

    // EventUpload
    struct EventUpload {
        uint256 batchId;
        uint256 count;
        EventUploadData[] events;
    }

    struct EventUploadData {
        uint256 eventId;
        // bytes32 bizType;
        // uint256 bizId;
        WithdrawData[] withdraws;
        Settlement[] settlements;
        Liquidation[] liquidations;
        uint256[] sequence;
    }

    struct WithdrawData {
        bytes32 accountId;
        address addr;
        uint256 amount;
        bytes32 symbol;
        uint256 chainId; // target withdraw chain
    }

    struct Settlement {
        bytes32 accountId;
        int256 settledAmount;
        bytes32 settledAsset;
        uint256 insuranceTransferAmount;
        SettlementExecution[] settlementExecutions;
    }

    struct Liquidation {
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

    struct SettlementExecution {
        bytes32 symbol;
        int256 sumUnitaryFundings;
        uint256 markPrice;
        int256 settledAmount;
    }
}

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

    // EventUploadData
    // bizType: 
    // 1 - withdraw
    // 2 -settlement
    // 3 - adl
    // 4 - liquidation
    // 5 - feeDistribution
    // 6 - delegateSigner
    // 7 - delegateWithdraw
    // 8 - adlV2
    // 9 - liquidationV2
    // 10 - withdrawSol
    // 11 - withdraw2Contract
    // 12 - balanceTransfer
    // 13 - swapResult
    // 14 - withdraw2ContractV2
    struct EventUploadData {
        uint8 bizType; 
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

    // WithdrawDataSol
    struct WithdrawDataSol {
        uint128 tokenAmount;
        uint128 fee;
        uint256 chainId; // target withdraw chain
        bytes32 accountId;
        bytes32 r;
        bytes32 s;
        bytes32 sender;
        bytes32 receiver;
        uint64 withdrawNonce;
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

    struct AdlV2 {
        bytes32 accountId;
        bytes32 symbolHash;
        int128 positionQtyTransfer;
        int128 costPositionTransfer;
        uint128 adlPrice;
        int128 sumUnitaryFundings;
        uint64 timestamp;
        bool isInsuranceAccount;
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

    struct LiquidationV2 {
        bytes32 accountId;
        bytes32 liquidatedAssetHash;
        int128 insuranceTransferAmount;
        uint64 timestamp;
        bool isInsuranceAccount;
        LiquidationTransferV2[] liquidationTransfers;
    }

    struct LiquidationTransferV2 {
        bytes32 symbolHash;
        int128 positionQtyTransfer;
        int128 costPositionTransfer;
        int128 fee;
        uint128 markPrice;
        int128 sumUnitaryFundings;
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

    enum VaultEnum {
        ProtocolVault,
        UserVault,
        Ceffu
    }

    struct Withdraw2Contract {
        uint128 tokenAmount;
        uint128 fee;
        uint256 chainId; // target withdraw chain
        bytes32 accountId;
        VaultEnum vaultType;
        address sender;
        uint64 withdrawNonce;
        address receiver; // maybe optional?
        uint64 timestamp;
        bytes32 brokerHash;
        bytes32 tokenHash;
        uint256 clientId;
    }

    /// @dev Balance transfer event structure for tracking inter-account transfers
    struct BalanceTransfer {
        bytes32 fromAccountId;   /// @dev Source account ID
        bytes32 toAccountId;     /// @dev Destination account ID
        uint128 amount;          /// @dev Transfer amount
        bytes32 tokenHash;       /// @dev Token hash identifier
        bool isFromAccountId;    /// @dev true: debit event, false: credit event
        uint8 transferType;      /// @dev Transfer type - see ILedgerEvent.BalanceTransfer for full enumeration
        uint256 transferId;      /// @dev Unique identifier to link debit/credit pairs
    }

    /// @dev Enum to track which side of the transfer has been processed
    enum TransferSide { 
        None,   /// @dev No events processed yet
        Debit,  /// @dev Only debit event processed
        Credit, /// @dev Only credit event processed
        Both    /// @dev Both debit and credit events processed
    }
    
    /// @dev Track the state of an internal transfer
    struct InternalTransferTrack {
        TransferSide side;   /// @dev Which side(s) have been processed
        bytes32 tokenHash;   /// @dev Token being transferred
        uint128 amount;      /// @dev Amount being transferred
    }

    struct SwapResult {
        bytes32 accountId;
        bytes32 buyTokenHash;
        bytes32 sellTokenHash;
        int128 buyQuantity;
        int128 sellQuantity;
        uint256 chainId;
        uint8 swapStatus; // OFF_CHAIN_SUCCESS(0), ON_CHAIN_SUCCESS(1), ON_CHAIN_FAILED(2)
    }

    enum ChainType {
        EVM,
        SOL
    }

    struct Withdraw2ContractV2 {
        uint128 tokenAmount;
        uint128 fee;
        ChainType senderChainType;
        ChainType receiverChainType;
        uint256 chainId; // target withdraw chain
        bytes32 accountId;
        VaultEnum vaultType;
        bytes32 sender; // Support Solana account and EVM address
        uint64 withdrawNonce;
        bytes32 receiver;
        uint64 timestamp;
        bytes32 brokerHash;
        bytes32 tokenHash;
        uint256 clientId;
    }

    // SetBrokerData - for cross-chain broker addition or removal
    struct SetBrokerData {
        bytes32 brokerHash;  // The hash of the broker to be added or removed
        uint256 dstChainId;  // The destination chain ID where broker should be modified
        bool allowed;        // true = add broker, false = remove broker
    }
}

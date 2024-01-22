// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

interface ILedgerEvent {
    event AccountRegister(bytes32 indexed accountId, bytes32 indexed brokerId, address indexed userAddress);
    event AccountDeposit(
        bytes32 indexed accountId,
        uint64 indexed depositNonce,
        uint64 indexed eventId,
        address userAddress,
        bytes32 tokenHash,
        uint128 tokenAmount,
        uint256 srcChainId,
        uint64 srcChainDepositNonce,
        bytes32 brokerHash
    );
    event AccountWithdrawApprove(
        bytes32 indexed accountId,
        uint64 indexed withdrawNonce,
        uint64 indexed eventId,
        bytes32 brokerHash,
        address sender,
        address receiver,
        uint256 chainId,
        bytes32 tokenHash,
        uint128 tokenAmount,
        uint128 fee
    );
    event AccountWithdrawFinish(
        bytes32 indexed accountId,
        uint64 indexed withdrawNonce,
        uint64 indexed eventId,
        bytes32 brokerHash,
        address sender,
        address receiver,
        uint256 chainId,
        bytes32 tokenHash,
        uint128 tokenAmount,
        uint128 fee
    );
    event AccountWithdrawFail(
        bytes32 indexed accountId,
        uint64 indexed withdrawNonce,
        uint64 indexed eventId,
        bytes32 brokerHash,
        address sender,
        address receiver,
        uint256 chainId,
        bytes32 tokenHash,
        uint128 tokenAmount,
        uint128 fee,
        uint8 failReson
    );

    event SettlementResult(
        uint64 indexed eventId,
        bytes32 indexed accountId,
        int128 settledAmount,
        bytes32 settledAssetHash,
        bytes32 insuranceAccountId,
        uint128 insuranceTransferAmount,
        uint64 settlementExecutionsCount,
        uint64 lastEngineEventId
    );

    event AdlResult(
        uint64 indexed eventId,
        bytes32 indexed accountId,
        bytes32 insuranceAccountId,
        bytes32 symbolHash,
        int128 positionQtyTransfer,
        int128 costPositionTransfer,
        uint128 adlPrice,
        int128 sumUnitaryFundings,
        uint64 lastEngineEventId
    );

    event LiquidationResult(
        uint64 indexed eventId,
        bytes32 indexed liquidatedAccountId,
        bytes32 indexed insuranceAccountId,
        bytes32 liquidatedAssetHash,
        uint128 insuranceTransferAmount,
        uint64 lastEngineEventId
    );

    event ProcessValidatedFutures(
        bytes32 indexed accountId,
        bytes32 indexed symbolHash,
        bytes32 feeAssetHash,
        int128 tradeQty,
        int128 notional,
        uint128 executedPrice,
        int128 fee,
        int128 sumUnitaryFundings,
        uint64 tradeId,
        uint64 matchId,
        uint64 timestamp,
        bool side
    );

    event SettlementExecution(
        bytes32 indexed symbolHash, uint128 markPrice, int128 sumUnitaryFundings, int128 settledAmount
    );
    event LiquidationTransfer(
        uint64 indexed liquidationTransferId,
        bytes32 indexed liquidatorAccountId,
        bytes32 indexed symbolHash,
        int128 positionQtyTransfer,
        int128 costPositionTransfer,
        int128 liquidatorFee,
        int128 insuranceFee,
        int128 liquidationFee,
        uint128 markPrice,
        int128 sumUnitaryFundings
    );

    event FeeDistribution(
        uint64 indexed eventId,
        bytes32 indexed fromAccountId,
        bytes32 indexed toAccountId,
        uint128 amount,
        bytes32 tokenHash
    );

    event DelegateSigner(
        uint64 indexed eventId,
        uint256 indexed chainId,
        bytes32 indexed accountId,
        address delegateContract,
        bytes32 brokerHash,
        address delegateSigner
    );

    event ChangeOperatorManager(address oldAddress, address newAddress);
    event ChangeCrossChainManager(address oldAddress, address newAddress);
    event ChangeVaultManager(address oldAddress, address newAddress);
    event ChangeMarketManager(address oldAddress, address newAddress);
    event ChangeFeeManager(address oldAddress, address newAddress);
    event ChangeLedgerImplA(address oldAddress, address newAddress);

    // All events below are deprecated
    // Keep them for indexer backward compatibility

    // @deprecated
    event AccountRegister(
        bytes32 indexed accountId, bytes32 indexed brokerId, address indexed userAddress, uint256 blocktime
    );
    // @deprecated
    event AccountDeposit(
        bytes32 indexed accountId,
        uint64 indexed depositNonce,
        uint64 indexed eventId,
        address userAddress,
        bytes32 tokenHash,
        uint128 tokenAmount,
        uint256 srcChainId,
        uint64 srcChainDepositNonce,
        bytes32 brokerHash,
        uint256 blocktime
    );
    // @deprecated
    event AccountWithdrawApprove(
        bytes32 indexed accountId,
        uint64 indexed withdrawNonce,
        uint64 indexed eventId,
        bytes32 brokerHash,
        address sender,
        address receiver,
        uint256 chainId,
        bytes32 tokenHash,
        uint128 tokenAmount,
        uint128 fee,
        uint256 blocktime
    );
    // @deprecated
    event AccountWithdrawFinish(
        bytes32 indexed accountId,
        uint64 indexed withdrawNonce,
        uint64 indexed eventId,
        bytes32 brokerHash,
        address sender,
        address receiver,
        uint256 chainId,
        bytes32 tokenHash,
        uint128 tokenAmount,
        uint128 fee,
        uint256 blocktime
    );
    // @deprecated
    event AccountWithdrawFail(
        bytes32 indexed accountId,
        uint64 indexed withdrawNonce,
        uint64 indexed eventId,
        bytes32 brokerHash,
        address sender,
        address receiver,
        uint256 chainId,
        bytes32 tokenHash,
        uint128 tokenAmount,
        uint128 fee,
        uint256 blocktime,
        uint8 failReson
    );
    // @deprecated
    event ProcessValidatedFutures(
        bytes32 indexed accountId,
        bytes32 indexed symbolHash,
        bytes32 feeAssetHash,
        int128 tradeQty,
        int128 notional,
        uint128 executedPrice,
        uint128 fee,
        int128 sumUnitaryFundings,
        uint64 tradeId,
        uint64 matchId,
        uint64 timestamp,
        bool side
    );
}

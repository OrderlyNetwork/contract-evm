// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types/AccountTypes.sol";
import "../library/types/PerpTypes.sol";
import "../library/types/EventTypes.sol";
import "../library/types/MarketTypes.sol";
import "./ILedgerError.sol";

interface ILedger is ILedgerError {
    event AccountRegister(
        bytes32 indexed accountId, bytes32 indexed brokerId, address indexed userAddress, uint256 blocktime
    );
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

    event SettlementResult(
        uint64 indexed eventId,
        bytes32 indexed accountId,
        int128 settledAmount,
        bytes32 settledAssetHash,
        bytes32 insuranceAccountId,
        uint128 insuranceTransferAmount,
        uint64 settlementExecutionsCount,
        uint64 lastCefiEventId
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
        uint64 lastCefiEventId
    );

    event LiquidationResult(
        uint64 indexed eventId,
        bytes32 indexed liquidatedAccountId,
        bytes32 indexed insuranceAccountId,
        bytes32 liquidatedAssetHash,
        uint128 insuranceTransferAmount,
        uint64 lastCefiEventId
    );

    function initialize() external;

    // called by cross chain manager
    function accountDeposit(AccountTypes.AccountDeposit calldata accountDeposit) external;
    function accountWithDrawFinish(AccountTypes.AccountWithdraw calldata withdraw) external;

    // called by operator manager
    function executeProcessValidatedFutures(PerpTypes.FuturesTradeUpload calldata trade) external;
    function executeWithdrawAction(EventTypes.WithdrawData calldata withdraw, uint64 eventId) external;
    function executeSettlement(EventTypes.Settlement calldata ledger, uint64 eventId) external;
    function executeLiquidation(EventTypes.Liquidation calldata liquidation, uint64 eventId) external;
    function executeAdl(EventTypes.Adl calldata adl, uint64 eventId) external;

    // view call
    function getFrozenWithdrawNonce(bytes32 accountId, uint64 withdrawNonce, bytes32 tokenHash)
        external
        view
        returns (uint128);
    // omni view call
    function batchGetUserLedger(bytes32[] calldata accountIds, bytes32[] memory tokens, bytes32[] memory symbols)
        external
        view
        returns (AccountTypes.AccountSnapshot[] memory);
    function batchGetUserLedger(bytes32[] calldata accountIds)
        external
        view
        returns (AccountTypes.AccountSnapshot[] memory);

    // admin call
    function setOperatorManagerAddress(address _operatorManagerAddress) external;
    function setCrossChainManager(address _crossChainManagerAddress) external;
    function setVaultManager(address _vaultManagerAddress) external;
    function setMarketManager(address _marketManagerAddress) external;
    function setFeeManager(address _feeManagerAddress) external;
}

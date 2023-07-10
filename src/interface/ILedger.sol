// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types/AccountTypes.sol";
import "../library/types/PerpTypes.sol";
import "../library/types/EventTypes.sol";
import "../library/types/MarketTypes.sol";

interface ILedger {
    error OnlyOperatorCanCall();
    error OnlyCrossChainManagerCanCall();
    error TotalSettleAmountNotMatch(int128 amount);
    error BalanceNotEnough(uint128 balance, int128 amount);
    error InsuranceTransferToSelf();
    error InsuranceTransferAmountInvalid(uint128 balance, uint128 insuranceTransferAmount, int128 settledAmount);
    error UserPerpPositionQtyZero(bytes32 accountId, bytes32 symbolHash);
    error InsurancePositionQtyInvalid(int128 adlPositionQtyTransfer, int128 userPositionQty);
    error AccountIdInvalid();
    error TokenNotAllowed(bytes32 tokenHash, uint256 chainId);
    error BrokerNotAllowed();

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
        bytes32 indexed accountId,
        int128 settledAmount,
        bytes32 settledAssetHash,
        bytes32 insuranceAccountId,
        uint128 insuranceTransferAmount,
        uint64 settlementExecutionsCount,
        uint64 eventId
    );

    event AdlResult(
        bytes32 indexed accountId,
        bytes32 insuranceAccountId,
        bytes32 symbolHash,
        int128 positionQtyTransfer,
        int128 costPositionTransfer,
        uint128 adlPrice,
        int128 sumUnitaryFundings,
        uint64 eventId
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
    function executePerpMarketInfo(MarketTypes.PerpMarketUpload calldata data) external;

    // view call
    function getUserLedgerBalance(bytes32 accountId, bytes32 symbol) external view returns (uint128);
    function getUserLedgerBrokerHash(bytes32 accountId) external view returns (bytes32);
    function getUserLedgerLastCefiEventId(bytes32 accountId) external view returns (uint64);
    function getFrozenTotalBalance(bytes32 accountId, bytes32 tokenHash) external view returns (uint128);
    function getFrozenWithdrawNonce(bytes32 accountId, uint64 withdrawNonce, bytes32 tokenHash)
        external
        view
        returns (uint128);
    function getPerpPosition(bytes32 accountId, bytes32 symbolHash)
        external
        view
        returns (AccountTypes.PerpPosition memory);

    // admin call
    function setOperatorManagerAddress(address _operatorManagerAddress) external;
    function setCrossChainManager(address _crossChainManagerAddress) external;
    function setVaultManager(address _vaultManagerAddress) external;
    function setMarketManager(address _marketManagerAddress) external;
    function setFeeManager(address _feeManagerAddress) external;
}

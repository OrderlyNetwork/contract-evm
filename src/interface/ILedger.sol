// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types/AccountTypes.sol";
import "../library/types/PerpTypes.sol";
import "../library/types/EventTypes.sol";

interface ILedger {
    event AccountRegister(
        bytes32 indexed accountId,
        bytes32 indexed brokerId,
        address indexed userAddress,
        uint256 blocktime
    );
    event AccountDeposit(
        bytes32 indexed accountId,
        uint256 indexed depositNonce,
        uint256 indexed eventId,
        address userAddress,
        bytes32 tokenHash,
        uint256 tokenAmount,
        uint256 srcChainId,
        uint256 srcChainDepositNonce,
        uint256 blocktime
    );
    event AccountWithdrawApprove(
        bytes32 indexed accountId,
        uint64 indexed withdrawNonce,
        uint256 indexed eventId,
        bytes32 brokerHash,
        address sender,
        address receiver,
        uint256 chainId,
        bytes32 tokenHash,
        uint256 tokenAmount,
        uint256 fee,
        uint256 blocktime
    );
    event AccountWithdrawFinish(
        bytes32 indexed accountId,
        uint64 indexed withdrawNonce,
        uint256 indexed eventId,
        bytes32 brokerHash,
        address sender,
        address receiver,
        uint256 chainId,
        bytes32 tokenHash,
        uint256 tokenAmount,
        uint256 fee,
        uint256 blocktime
    );
    event AccountWithdrawFail(
        bytes32 indexed accountId,
        uint64 indexed withdrawNonce,
        uint256 indexed eventId,
        bytes32 brokerHash,
        address sender,
        address receiver,
        uint256 chainId,
        bytes32 tokenHash,
        uint256 tokenAmount,
        uint256 fee,
        uint256 blocktime,
        uint8 failReson
    );

    // called by cross chain manager
    function accountDeposit(AccountTypes.AccountDeposit calldata accountDeposit) external;
    function accountWithDrawFinish(AccountTypes.AccountWithdraw calldata withdraw) external;

    // called by operator manager
    function updateUserLedgerByTradeUpload(PerpTypes.FuturesTradeUpload calldata trade) external;
    function executeWithdrawAction(EventTypes.WithdrawData calldata withdraw, uint256 eventId) external;
    function executeSettlement(EventTypes.LedgerData calldata ledger, uint256 eventId) external;
    function executeLiquidation(EventTypes.LiquidationData calldata liquidation, uint256 eventId) external;

    // view call
    function getUserLedgerBalance(bytes32 accountId, bytes32 symbol) external view returns (uint256);
    function getUserLedgerBrokerHash(bytes32 accountId) external view returns (bytes32);

    // admin call
    function setOperatorManagerAddress(address _operatorManagerAddress) external;
    function setInsuranceFundAccountId(bytes32 _insuranceFundAccountId) external;
    function setCrossChainManager(address _crossChainManagerAddress) external;
    function setVaultManager(address _vaultManagerAddress) external;
}

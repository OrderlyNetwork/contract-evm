// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types/AccountTypes.sol";
import "../library/types/PerpTypes.sol";

interface ILedger {
    event AccountRegister(bytes32 indexed accountId, bytes32 indexed brokerId, address indexed userAddress);
    event AccountDeposit(
        bytes32 indexed accountId,
        uint256 indexed depositNonce,
        uint256 indexed eventId,
        address userAddress,
        bytes32 tokenSymbol,
        uint256 tokenAmount,
        uint256 srcChainId,
        uint256 srcChainDepositNonce
    );
    event AccountWithdrawApprove(
        bytes32 indexed accountId,
        uint256 indexed withdrawNonce,
        uint256 indexed eventId,
        address userAddress,
        uint256 chainId,
        bytes32 tokenSymbol,
        uint256 tokenAmount
    );
    event AccountWithdrawFinish(
        bytes32 indexed accountId,
        uint256 indexed withdrawNonce,
        uint256 indexed eventId,
        address userAddress,
        uint256 chainId,
        bytes32 tokenSymbol,
        uint256 tokenAmount
    );
    event AccountWithdrawFail(
        bytes32 indexed accountId,
        uint256 indexed withdrawNonce,
        uint256 indexed eventId,
        address userAddress,
        uint256 chainId,
        bytes32 tokenSymbol,
        uint256 tokenAmount,
        uint8 failReason
    );

    // called by cross chain manager
    function accountDeposit(AccountTypes.AccountDeposit calldata accountDeposit) external;
    // function accountWithDrawFinish(PerpTypes.WithdrawData calldata withdraw, uint256 eventId) external;

    // called by operator manager
    function updateUserLedgerByTradeUpload(PerpTypes.FuturesTradeUpload calldata trade) external;
    function executeWithdrawAction(PerpTypes.WithdrawData calldata withdraw, uint256 eventId) external;
    function executeLedger(PerpTypes.LedgerData calldata ledger, uint256 eventId) external;
    function executeLiquidation(PerpTypes.LiquidationData calldata liquidation, uint256 eventId) external;

    // view call
    function getUserLedgerBalance(bytes32 accountId, bytes32 symbol) external view returns (uint256);
    function getUserLedgerBrokerId(bytes32 accountId) external view returns (bytes32);
}

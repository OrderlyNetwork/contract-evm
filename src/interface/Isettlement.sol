// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types/AccountTypes.sol";
import "../library/types/PerpTypes.sol";

interface Isettlement {
    function registerAccount(bytes32 accountId, address addr, uint256 brokerId) external;
    function updateUserLedgerByTradeUpload(PrepTypes.FuturesTradeUpload calldata trade) external;
    function executeWithdrawAction(PrepTypes.WithdrawData calldata withdraw, uint256 eventId) external;
    function executeSettlement(PrepTypes.Settlement calldata settlement, uint256 eventId) external;
    function executeLiquidation(PrepTypes.Liquidation calldata liquidation, uint256 eventId) external;
}

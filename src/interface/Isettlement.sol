// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types/account_types.sol";
import "../library/types/perp_types.sol";

interface Isettlement {
    function update_user_ledger_by_trade_upload(PrepTypes.FuturesTradeUpload calldata trade) external;
    function execute_withdraw_action(PrepTypes.WithdrawData calldata withdraw, uint256 event_id) external;
    function execute_settlement(PrepTypes.Settlement calldata settlement, uint256 event_id) external;
    function execute_liquidation(PrepTypes.Liquidation calldata liquidation, uint256 event_id) external;
}

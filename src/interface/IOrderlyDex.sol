// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types.sol";

interface IOrderlyDex {
    struct PerpPosition {
        int256 position_qty;
        int256 cost_position;
        int256 last_sum_unitary_fundings;
        uint256 last_executed_price;
    }

    struct Account {
        // user's balance
        uint256 balance;
        // last perp trade id
        uint256 last_perp_trade_id;
        // last cefi event id
        uint256 last_cefi_event_id;
        // perp position
        PerpPosition perp_position;
    }

    function update_user_ledger_by_trade_upload(Types.FuturesTradeUpload calldata trade) external;
    function execute_withdraw_action(Types.WithdrawData calldata withdraw, uint256 event_id) external;
    function execute_settlement(Types.Settlement calldata settlement, uint256 event_id) external;
    function execute_liquidation(Types.Liquidation calldata liquidation, uint256 event_id) external;
}

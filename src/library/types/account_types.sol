// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

library AccountTypes {
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
}

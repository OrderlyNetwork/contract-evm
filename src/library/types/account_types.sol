// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

// EnumerableSet
import "../../../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

library AccountTypes {
    using EnumerableSet for EnumerableSet.AddressSet;

    int256 constant FUNDING_MOVE_RIGHT_PRECISIONS = 100000000000000000;

    struct PerpPosition {
        int256 position_qty;
        int256 cost_position;
        int256 last_sum_unitary_fundings;
        uint256 last_executed_price;
    }

    struct Account {
        // account id, unique for each account, should be {Array<addr>, brokerId}
        bytes32 account_id;
        // user's broker id
        uint256 broker_id;
        // account addresses.
        EnumerableSet.AddressSet addresses;
        // user's balance
        uint256 balance;
        // last perp trade id
        uint256 last_perp_trade_id;
        // last cefi event id
        uint256 last_cefi_event_id;
        // perp position
        PerpPosition perp_position;
        // reentrancy lock
        bool has_pending_settlement_request;
    }

    // charge funding fee
    function chargeFundingFee(PerpPosition storage position, int256 sumUnitaryFundings) public {
        int256 accruedFeeUncoverted = position.position_qty * (sumUnitaryFundings - position.last_sum_unitary_fundings);
        int256 accruedFee = accruedFeeUncoverted / FUNDING_MOVE_RIGHT_PRECISIONS;
        int256 remainder = accruedFeeUncoverted - (accruedFee * FUNDING_MOVE_RIGHT_PRECISIONS);
        if (remainder > 0) {
            accruedFee += 1;
        }
        position.cost_position += accruedFee;
        position.last_sum_unitary_fundings = sumUnitaryFundings;
    }
}

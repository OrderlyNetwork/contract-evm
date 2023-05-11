// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

// EnumerableSet
import "../../../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

library AccountTypes {
    using EnumerableSet for EnumerableSet.AddressSet;

    int256 constant FUNDING_MOVE_RIGHT_PRECISIONS = 100000000000000000;

    struct PerpPosition {
        int256 positionQty;
        int256 cost_position;
        int256 lastSumUnitaryFundings;
        uint256 last_executed_price;
    }

    struct Account {
        // account id, unique for each account, should be {Array<addr>, brokerId}
        bytes32 accountId;
        // user's broker id
        uint256 brokerId;
        // account addresses.
        EnumerableSet.AddressSet addresses;
        // user's balance
        uint256 balance;
        // last perp trade id
        uint256 lastPerpTradeId;
        // last cefi event id
        uint256 lastCefiEventId;
        // perp position
        PerpPosition perpPosition;
        // reentrancy lock
        bool hasPendingSettlementRequest;
    }

    struct AccountRegister {
        bytes32 accountId;
        uint256 brokerId;
        address addr;
    }

    // charge funding fee
    function chargeFundingFee(PerpPosition storage position, int256 sumUnitaryFundings) public {
        int256 accruedFeeUncoverted = position.positionQty * (sumUnitaryFundings - position.lastSumUnitaryFundings);
        int256 accruedFee = accruedFeeUncoverted / FUNDING_MOVE_RIGHT_PRECISIONS;
        int256 remainder = accruedFeeUncoverted - (accruedFee * FUNDING_MOVE_RIGHT_PRECISIONS);
        if (remainder > 0) {
            accruedFee += 1;
        }
        position.cost_position += accruedFee;
        position.lastSumUnitaryFundings = sumUnitaryFundings;
    }
}

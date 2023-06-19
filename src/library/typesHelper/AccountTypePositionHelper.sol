// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../types/AccountTypes.sol";

library AccountTypePositionHelper {
    int256 constant FUNDING_MOVE_RIGHT_PRECISIONS = 1e17; // 1e17
    int256 constant PRICE_QTY_MOVE_RIGHT_PRECISIONS = 1e10; // 1e10
    int32 constant MARGIN_100PERCENT = 1e4; // 1e4

    // charge funding fee
    function chargeFundingFee(AccountTypes.PerpPosition storage position, int256 sumUnitaryFundings) internal {
        int256 accruedFeeUncoverted = position.positionQty * (sumUnitaryFundings - position.lastSumUnitaryFundings);
        int256 accruedFee = accruedFeeUncoverted / FUNDING_MOVE_RIGHT_PRECISIONS;
        int256 remainder = accruedFeeUncoverted - (accruedFee * FUNDING_MOVE_RIGHT_PRECISIONS);
        if (remainder > 0) {
            accruedFee += 1;
        }
        position.costPosition += accruedFee;
        position.lastSumUnitaryFundings = sumUnitaryFundings;
    }

    // cal pnl
    function calPnl(AccountTypes.PerpPosition storage position, int256 markPrice) internal view returns (int256) {
        return position.positionQty * markPrice / FUNDING_MOVE_RIGHT_PRECISIONS - position.costPosition;
    }

    // maintenance margin
    function maintenanceMargin(
        AccountTypes.PerpPosition storage position,
        int256 markPrice,
        int256 baseMaintenanceMargin
    ) internal view returns (int256) {
        return abs(position.positionQty) * markPrice / PRICE_QTY_MOVE_RIGHT_PRECISIONS * baseMaintenanceMargin
            / int256(MARGIN_100PERCENT);
    }

    // is full settled
    function isFullSettled(AccountTypes.PerpPosition storage position) internal view returns (bool) {
        return position.positionQty == 0 || position.costPosition == 0;
    }

    /// only change averageEntryPrice, openingCost
    /// params:
    ///     qty: decimal is 8
    ///     price: decimal is 8
    ///     liquidationQuoteDiff: decimal is 6
    /// for:
    ///     perp trade: liquidationQuoteDiff should be empty
    ///     liquidation: liquidationQuoteDiff should no be empty
    function calAverageEntryPrice(
        AccountTypes.PerpPosition storage position,
        int256 qty,
        int256 price,
        int256 liquidationQuoteDiff
    ) internal {
        if (qty == 0) {
            return;
        }
        int256 currentHolding = position.positionQty + qty;
        if (currentHolding == 0) {
            position.averageEntryPrice = 0;
            position.openingCost = 0;
            return;
        }
        int256 quoteDiff = liquidationQuoteDiff != 0 ? liquidationQuoteDiff * 1e8 : -qty * price;
        int256 openingCost = position.openingCost * 1e8;
        if (position.positionQty * currentHolding > 0) {
            if (qty * position.positionQty > 0) {
                openingCost += quoteDiff;
            } else {
                int256 v = halfUp24_8(openingCost * qty, position.positionQty);
                openingCost += v;
            }
        } else {
            openingCost = halfUp24_8(quoteDiff * currentHolding, qty);
        }
        position.averageEntryPrice = uint256(halfDown16_8(-openingCost, currentHolding));
        position.openingCost = halfUp16_8(openingCost, 1e8);
    }

    /// dividend has move right 24 precisions, divisor move right 8
    function halfUp24_8(int256 dividend, int256 divisor) internal pure returns (int256) {
        // to eliminate effects of dividend extra move right 8 precision in outer
        return halfUp16_8(dividend, divisor * 1e8) * 1e8;
    }

    /// HALF UP
    /// Rounding mode to round towards "nearest neighbor"
    /// unless both neighbors are equidistant, in which case round up.
    /// Behaves as for RoundingMode UP if the discarded
    /// fraction is >=0.5;
    /// half up
    /// 5.5 -> 6
    /// 2.5 -> 3
    /// 1.6 -> 2
    /// 1.1 -> 1
    /// 1.0 -> 1
    /// -1.0 -> -1
    /// -1.1 -> -1
    /// -1.6 -> -2
    /// -2.5 -> -3
    /// -5.5 -> -6
    function halfUp16_8(int256 dividend, int256 divisor) internal pure returns (int256) {
        int256 quotient = dividend / divisor;
        int256 remainder = dividend % divisor;
        if (abs(remainder) * 2 >= abs(divisor)) {
            if (quotient > 0) {
                quotient += 1;
            } else {
                quotient -= 1;
            }
        }
        return quotient;
    }

    /// HALF DOWN
    /// Rounding mode to round towards "nearest neighbor"
    /// unless both neighbors are equidistant, in which case round
    /// down.  Behaves as for RoundingMode UP if the discarded
    /// fraction is > 0.5;
    /// Example:
    /// 5.5 -> 5
    /// 2.5 -> 2
    /// 1.6 -> 2
    /// 1.1 -> 1
    /// 1.0 -> 1
    /// -1.0 -> -1
    /// -1.1 -> -1
    /// -1.6 -> -2
    /// -2.5 -> -2
    /// -5.5 -> -5
    function halfDown16_8(int256 dividend, int256 divisor) internal pure returns (int256) {
        int256 quotient = dividend / divisor;
        int256 remainder = dividend % divisor;
        if (abs(remainder) * 2 > abs(divisor)) {
            if (quotient > 0) {
                quotient += 1;
            } else {
                quotient -= 1;
            }
        }
        return quotient;
    }

    function abs(int256 value) internal pure returns (int256) {
        return value > 0 ? value : -value;
    }
}

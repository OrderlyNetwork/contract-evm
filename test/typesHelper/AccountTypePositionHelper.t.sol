// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/library/typesHelper/AccountTypePositionHelper.sol";

contract AccountTypePositionHelperTest is Test {
    using AccountTypePositionHelper for AccountTypes.PerpPosition;

    AccountTypes.PerpPosition position;

    function test_halfUp16_8() public {
        {
            int128 a = AccountTypePositionHelper.halfUp16_8(10, 11);
            assertEq(a, 1);
            int128 b = AccountTypePositionHelper.halfUp16_8(12, 11);
            assertEq(b, 1);
            int128 c = AccountTypePositionHelper.halfUp16_8(17, 11);
            assertEq(c, 2);
            int128 d = AccountTypePositionHelper.halfUp16_8(21, 11);
            assertEq(d, 2);
            int128 e = AccountTypePositionHelper.halfUp16_8(22, 11);
            assertEq(e, 2);
        }
        {
            int128 a = AccountTypePositionHelper.halfUp16_8(4, 10);
            assertEq(a, 0);
            int128 b = AccountTypePositionHelper.halfUp16_8(5, 10);
            assertEq(b, 1);
            int128 c = AccountTypePositionHelper.halfUp16_8(6, 10);
            assertEq(c, 1);
            int128 d = AccountTypePositionHelper.halfUp16_8(14, 10);
            assertEq(d, 1);
            int128 e = AccountTypePositionHelper.halfUp16_8(15, 10);
            assertEq(e, 2);
            int128 f = AccountTypePositionHelper.halfUp16_8(16, 10);
            assertEq(f, 2);
        }
        {
            int128 a = AccountTypePositionHelper.halfUp16_8(-10, 11);
            assertEq(a, -1);
            int128 b = AccountTypePositionHelper.halfUp16_8(-12, 11);
            assertEq(b, -1);
            int128 c = AccountTypePositionHelper.halfUp16_8(-17, 11);
            assertEq(c, -2);
            int128 d = AccountTypePositionHelper.halfUp16_8(-21, 11);
            assertEq(d, -2);
            int128 e = AccountTypePositionHelper.halfUp16_8(-22, 11);
            assertEq(e, -2);
        }
        {
            int128 a = AccountTypePositionHelper.halfUp16_8(-4, 10);
            assertEq(a, 0);
            int128 b = AccountTypePositionHelper.halfUp16_8(-5, 10);
            assertEq(b, -1);
            int128 c = AccountTypePositionHelper.halfUp16_8(-6, 10);
            assertEq(c, -1);
            int128 d = AccountTypePositionHelper.halfUp16_8(-14, 10);
            assertEq(d, -1);
            int128 e = AccountTypePositionHelper.halfUp16_8(-15, 10);
            assertEq(e, -2);
            int128 f = AccountTypePositionHelper.halfUp16_8(-16, 10);
            assertEq(f, -2);
        }
    }

    function test_halfDown16_8() public {
        {
            int128 a = AccountTypePositionHelper.halfDown16_8(10, 11);
            assertEq(a, 1);
            int128 b = AccountTypePositionHelper.halfDown16_8(12, 11);
            assertEq(b, 1);
            int128 c = AccountTypePositionHelper.halfDown16_8(17, 11);
            assertEq(c, 2);
            int128 d = AccountTypePositionHelper.halfDown16_8(21, 11);
            assertEq(d, 2);
            int128 e = AccountTypePositionHelper.halfDown16_8(22, 11);
            assertEq(e, 2);
        }
        {
            int128 a = AccountTypePositionHelper.halfDown16_8(4, 10);
            assertEq(a, 0);
            int128 b = AccountTypePositionHelper.halfDown16_8(5, 10);
            assertEq(b, 0);
            int128 c = AccountTypePositionHelper.halfDown16_8(6, 10);
            assertEq(c, 1);
            int128 d = AccountTypePositionHelper.halfDown16_8(14, 10);
            assertEq(d, 1);
            int128 e = AccountTypePositionHelper.halfDown16_8(15, 10);
            assertEq(e, 1);
            int128 f = AccountTypePositionHelper.halfDown16_8(16, 10);
            assertEq(f, 2);
        }
        {
            int128 a = AccountTypePositionHelper.halfDown16_8(-10, 11);
            assertEq(a, -1);
            int128 b = AccountTypePositionHelper.halfDown16_8(-12, 11);
            assertEq(b, -1);
            int128 c = AccountTypePositionHelper.halfDown16_8(-17, 11);
            assertEq(c, -2);
            int128 d = AccountTypePositionHelper.halfDown16_8(-21, 11);
            assertEq(d, -2);
            int128 e = AccountTypePositionHelper.halfDown16_8(-22, 11);
            assertEq(e, -2);
        }
        {
            int128 a = AccountTypePositionHelper.halfDown16_8(-4, 10);
            assertEq(a, 0);
            int128 b = AccountTypePositionHelper.halfDown16_8(-5, 10);
            assertEq(b, 0);
            int128 c = AccountTypePositionHelper.halfDown16_8(-6, 10);
            assertEq(c, -1);
            int128 d = AccountTypePositionHelper.halfDown16_8(-14, 10);
            assertEq(d, -1);
            int128 e = AccountTypePositionHelper.halfDown16_8(-15, 10);
            assertEq(e, -1);
            int128 f = AccountTypePositionHelper.halfDown16_8(-16, 10);
            assertEq(f, -2);
        }
    }

    function test_charge_funding_fee() public {
        position = AccountTypes.PerpPosition({
            positionQty: 1e6,
            costPosition: 0,
            lastSumUnitaryFundings: 1e15,
            lastExecutedPrice: 0,
            lastSettledPrice: 0,
            averageEntryPrice: 0,
            openingCost: 0,
            lastAdlPrice: 0
        });
        int128 lastSumUnitaryFundings = 1.1e15;
        position.chargeFundingFee(lastSumUnitaryFundings);
        assertEq(position.costPosition, 1e3);

        position.lastSumUnitaryFundings = 1e15;
        position.costPosition = 1e3;
        lastSumUnitaryFundings = 0.8e15;
        position.chargeFundingFee(lastSumUnitaryFundings);
        assertEq(position.costPosition, -1e3);

        position.lastSumUnitaryFundings = 1e15;
        position.costPosition = 0;
        lastSumUnitaryFundings = 1e15 + 1;
        position.chargeFundingFee(lastSumUnitaryFundings);
        assertEq(position.costPosition, 1);

        position.lastSumUnitaryFundings = 1e15;
        position.costPosition = 1e3;
        lastSumUnitaryFundings = 0.9e15 + 1;
        position.chargeFundingFee(lastSumUnitaryFundings);
        assertEq(position.costPosition, 1);

        position.lastSumUnitaryFundings = 1e15;
        position.costPosition = 0;
        position.positionQty = 1e8;
        lastSumUnitaryFundings = 1e15 - 1;
        position.chargeFundingFee(lastSumUnitaryFundings);
        assertEq(position.costPosition, 0);

        position.lastSumUnitaryFundings = 2e15 + 2;
        position.costPosition = 1e3;
        position.positionQty = -4e8;
        lastSumUnitaryFundings = 3e15 + 3;
        position.chargeFundingFee(lastSumUnitaryFundings);
        assertEq(position.costPosition, -3999000);

        position.lastSumUnitaryFundings = 2e15 + 2;
        position.costPosition = 1e3;
        position.positionQty = 4e8;
        lastSumUnitaryFundings = 3e15 + 3;
        position.chargeFundingFee(lastSumUnitaryFundings);
        assertEq(position.costPosition, 4001001);
    }

    function test_cal_average_entry_price() public {
        position = AccountTypes.PerpPosition({
            positionQty: 0,
            costPosition: 0,
            lastSumUnitaryFundings: 0,
            lastExecutedPrice: 0,
            lastSettledPrice: 0,
            averageEntryPrice: 0,
            openingCost: 0,
            lastAdlPrice: 0
        });

        position.calAverageEntryPrice(1e8, 1e11, 0);
        assertEq(position.openingCost, -1e11);
        assertEq(position.averageEntryPrice, 1e11);

        position.positionQty = 1e8;
        position.calAverageEntryPrice(1e8, 2e11, 0);
        assertEq(position.openingCost, -3e11);
        assertEq(position.averageEntryPrice, 1.5e11);

        position.positionQty = 2e8;
        position.calAverageEntryPrice(-1e8, 3e11, 0);
        assertEq(position.openingCost, -1.5e11);
        assertEq(position.averageEntryPrice, 1.5e11);

        position.positionQty = 1e8;
        position.calAverageEntryPrice(-2e8, 3e11, 0);
        assertEq(position.openingCost, 3e11);
        assertEq(position.averageEntryPrice, 3e11);
    }

    // https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/250052731/CeFi+avg+open+price+calculation#Corner-cases
    function test_average_entry_price_corner_case() public {
        position = AccountTypes.PerpPosition({
            positionQty: 0,
            costPosition: 0,
            lastSumUnitaryFundings: 0,
            lastExecutedPrice: 0,
            lastSettledPrice: 0,
            averageEntryPrice: 0,
            openingCost: 0,
            lastAdlPrice: 0
        });

        // buy 1.11111 @ 2.22222
        position.calAverageEntryPrice(111_111_000, 222_222_000, 0);
        assertEq(position.openingCost, -246_913_086);
        assertEq(position.averageEntryPrice, 222_222_000);

        // sell 0.12345 @ 2.66666
        position.positionQty = 111_111_000;
        position.calAverageEntryPrice(-12_345_000, 266_666_000, 0);
        assertEq(position.openingCost, -219_479_780);
        assertEq(position.averageEntryPrice, 222_221_999);

        // sell 1.56789 @ 2.88888
        position.positionQty = 98_766_000;
        position.calAverageEntryPrice(-156_789_000, 288_888_000, 0);
        assertEq(position.openingCost, 167_621_484);
        assertEq(position.averageEntryPrice, 288_888_000);

        // sell 1.98765 @ 2.22222
        position.positionQty = -58_023_000;
        position.calAverageEntryPrice(-198_765_000, 222_222_000, 0);
        assertEq(position.openingCost, 609_321_042);
        assertEq(position.averageEntryPrice, 237_285_637);
    }

    function test_half_down_up_boundary() public {
        // half_down16_8
        int128 openingCost = -50_000_000_000_000_000;
        int128 holding = 200_000_000;
        int128 perpPosition = AccountTypePositionHelper.halfDown16_8(openingCost, holding);
        assertEq(perpPosition, -250_000_000);

        openingCost = -50_000_000_100_000_000;
        holding = 200_000_000;
        perpPosition = AccountTypePositionHelper.halfDown16_8(openingCost, holding);
        assertEq(perpPosition, -250_000_000);

        openingCost = -50_000_000_100_000_001;
        holding = 200_000_000;
        perpPosition = AccountTypePositionHelper.halfDown16_8(openingCost, holding);
        assertEq(perpPosition, -250_000_001);

        openingCost = 50_000_000_000_000_000;
        holding = 200_000_000;
        perpPosition = AccountTypePositionHelper.halfDown16_8(openingCost, holding);
        assertEq(perpPosition, 250_000_000);

        openingCost = 50_000_000_100_000_000;
        holding = 200_000_000;
        perpPosition = AccountTypePositionHelper.halfDown16_8(openingCost, holding);
        assertEq(perpPosition, 250_000_000);

        openingCost = 50_000_000_100_000_001;
        holding = 200_000_000;
        perpPosition = AccountTypePositionHelper.halfDown16_8(openingCost, holding);
        assertEq(perpPosition, 250_000_001);

        // half_up24_8
        openingCost = -5_000_000_000_000_000_000_000_000;
        holding = 200_000_000;
        perpPosition = AccountTypePositionHelper.halfUp24_8(openingCost, holding);
        assertEq(perpPosition, -25_000_000_000_000_000);

        openingCost = -5_000_000_009_999_999_900_000_000;
        holding = 200_000_000;
        perpPosition = AccountTypePositionHelper.halfUp24_8(openingCost, holding);
        assertEq(perpPosition, -25_000_000_000_000_000);

        openingCost = -5_000_000_010_000_000_000_000_000;
        holding = 200_000_000;
        perpPosition = AccountTypePositionHelper.halfUp24_8(openingCost, holding);
        assertEq(perpPosition, -25_000_000_100_000_000);

        openingCost = 5_000_000_000_000_000_000_000_000;
        holding = 200_000_000;
        perpPosition = AccountTypePositionHelper.halfUp24_8(openingCost, holding);
        assertEq(perpPosition, 25_000_000_000_000_000);

        openingCost = 5_000_000_009_999_999_900_000_000;
        holding = 200_000_000;
        perpPosition = AccountTypePositionHelper.halfUp24_8(openingCost, holding);
        assertEq(perpPosition, 25_000_000_000_000_000);

        openingCost = 5_000_000_010_000_000_000_000_000;
        holding = 200_000_000;
        perpPosition = AccountTypePositionHelper.halfUp24_8(openingCost, holding);
        assertEq(perpPosition, 25_000_000_100_000_000);
    }

    function test_huge_holding() public {
        position = AccountTypes.PerpPosition({
            positionQty: 1_000_000_000_000_000,
            costPosition: 0,
            lastSumUnitaryFundings: 0,
            lastExecutedPrice: 0,
            lastSettledPrice: 0,
            averageEntryPrice: 200_000_000,
            openingCost: 0,
            lastAdlPrice: 0
        });

        // sell 20000000.11111 @ 2.22222
        position.calAverageEntryPrice(-2_000_000_011_111_000, 222_222_000, 0);
        assertEq(position.openingCost, 2222220024691086);
        assertEq(position.averageEntryPrice, 222222000);

        position = AccountTypes.PerpPosition({
            positionQty: 0,
            costPosition: 0,
            lastSumUnitaryFundings: 0,
            lastExecutedPrice: 0,
            lastSettledPrice: 0,
            averageEntryPrice: 0,
            openingCost: 0,
            lastAdlPrice: 0
        });

        // 100 billion*10^8
        int128 qtyDiff = 10_000_000_000_000_000_000;
        int128 price = 222_222_000;
        // sell 20000000.11111 @ 2.22222
        position.calAverageEntryPrice(qtyDiff, price, 0);
        assertEq(position.openingCost, -22222200000000000000);
        assertEq(position.averageEntryPrice, 222222000);
        position.positionQty += qtyDiff;
        position.calAverageEntryPrice(-2 * qtyDiff, price, 0);
        assertEq(position.openingCost, 22222200000000000000);
        assertEq(position.averageEntryPrice, 222222000);
    }
}

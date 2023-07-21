// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/library/typesHelper/SafeCastHelper.sol";

contract SafeCastHelperTest is Test {
    using SafeCastHelper for *;

    function test_cast_positive() public {
        uint128 y = 123;
        int128 z = y.toInt128();
        assertEq(z, 123);
        uint128 x = z.toUint128();
        assertEq(x, 123);
    }

    function test_cast_0() public {
        uint128 y = 0;
        int128 z = y.toInt128();
        assertEq(z, 0);
        uint128 x = z.toUint128();
        assertEq(x, 0);
    }

    function testRevert_cast_large_uint() public {
        uint128 y = 1 << 127;
        vm.expectRevert(abi.encodeWithSelector(SafeCastHelper.SafeCastOverflow.selector));
        int128 z = y.toInt128();
        z = z; // avoid warning, never reach here
    }

    function testRevert_cast_minus_int() public {
        int128 y = -1;
        vm.expectRevert(abi.encodeWithSelector(SafeCastHelper.SafeCastOverflow.selector));
        uint128 z = y.toUint128();
        z = z; // avoid warning, never reach here
    }

    function test_abs_positive() public {
        int128 x = 123;
        uint128 y = x.abs();
        assertEq(y, 123);
    }

    function test_abs_negative() public {
        int128 x = -123;
        uint128 y = x.abs();
        assertEq(y, 123);
    }

    function test_abs_min_int() public {
        int128 x = type(int128).min;
        uint128 y = x.abs();
        assertEq(y, 1 << 127);
    }

    function test_abs_i256_positive() public {
        int256 x = 123;
        uint256 y = x.abs_i256();
        assertEq(y, 123);
    }

    function test_abs_i256_negative() public {
        int256 x = -123;
        uint256 y = x.abs_i256();
        assertEq(y, 123);
    }

    function test_abs_i256_min_int() public {
        int256 x = type(int256).min;
        uint256 y = x.abs_i256();
        assertEq(y, 1 << 255);
    }
}

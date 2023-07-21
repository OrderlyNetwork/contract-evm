// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

library SafeCastHelper {
    error SafeCastOverflow();

    // cast uint128 to int128
    function toInt128(uint128 y) internal pure returns (int128 z) {
        if (y > uint128(type(int128).max)) revert SafeCastOverflow();
        z = int128(y);
    }

    // cast int128 to uint128
    function toUint128(int128 y) internal pure returns (uint128 z) {
        if (y < 0) revert SafeCastOverflow();
        z = uint128(y);
    }

    // safe abs 256
    function abs(int128 x) internal pure returns (uint128 y) {
        if (x == type(int128).min) {
            y = 1 << 127;
        } else {
            y = uint128(x < 0 ? -x : x);
        }
    }

    // safe abs int256
    function abs_i256(int256 x) internal pure returns (uint256 y) {
        if (x == type(int256).min) {
            y = 1 << 255;
        } else {
            y = uint256(x < 0 ? -x : x);
        }
    }
}

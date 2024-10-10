// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Bytes32ToAsciiBytes {
    function byteToHex(bytes1 b) internal pure returns (bytes1, bytes1) {
        bytes1 hi = bytes1(uint8(b) / 16);
        bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
        return (bytes1(uint8(hi) + (uint8(hi) < 10 ? 0x30 : 0x57)), bytes1(uint8(lo) + (uint8(lo) < 10 ? 0x30 : 0x57))); // 0x30 for '0'-'9' and 0x57 for 'a'-'f'
    }

    function bytes32ToAsciiBytes(bytes32 _input) internal pure returns (bytes memory) {
        bytes memory result = new bytes(64);

        for (uint256 i = 0; i < 32; i++) {
            (bytes1 hi, bytes1 lo) = byteToHex(_input[i]);
            result[2 * i] = hi;
            result[2 * i + 1] = lo;
        }

        return result;
    }
}

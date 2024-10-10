// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/library/Bytes32ToAsciiBytes.sol";

contract Bytes32ToAsciiBytesTest is Test {
    function test_bytes32ToAsciiBytes() public {
        bytes32 v = hex"4d741b6f1eb29cb2a9b9911c82f56fa8d73b04959d3d9d222895df6c0b28aa15";
        bytes memory m =
            hex"34643734316236663165623239636232613962393931316338326635366661386437336230343935396433643964323232383935646636633062323861613135";
        assertEq(Bytes32ToAsciiBytes.bytes32ToAsciiBytes(v), m);
    }
}

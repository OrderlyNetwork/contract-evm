// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/library/Utils.sol";

contract UtilsTest is Test {
    // https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/304513342/Account+ID+Calculation
    function test_calculateAccountId() public {
        assertEq(
            Utils.getAccountId(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, "ref_dex"),
            0x29783c8cfabffb495d176dda502c197c1ec61258c865c3a01c9573ad4934cf81
        );
    }

    function test_calculateStringHash() public {
        assertEq(
            Utils.calculateStringHash("ref_dex"), 0x7992f050dbd5f109a9eb7010a8f3a688214c047dd7f69b96a9774f556ccfa174
        );
    }

    function test_validateAccountId() public {
        assertTrue(
            Utils.validateAccountId(
                0x29783c8cfabffb495d176dda502c197c1ec61258c865c3a01c9573ad4934cf81,
                0x7992f050dbd5f109a9eb7010a8f3a688214c047dd7f69b96a9774f556ccfa174,
                0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
            )
        );
    }

    function test_toBytes32() public {
        assertEq(
            Utils.toBytes32(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4),
            hex"0000000000000000000000005B38Da6a701c568545dCfcB03FcB875f56beddC4"
        );
    }
}

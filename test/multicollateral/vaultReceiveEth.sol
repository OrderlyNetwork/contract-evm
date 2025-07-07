// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Vault} from "../../src/vaultSide/Vault.sol";


contract VaultReceiveEth is Vault {
    receive() external payable {
        // do nothing
    }
}

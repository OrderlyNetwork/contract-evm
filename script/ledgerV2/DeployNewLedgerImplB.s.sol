// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../../src/LedgerImplB.sol";
import "../utils/BaseScript.s.sol";
import "../utils/ConfigHelper.s.sol";

contract DeployNewLedgerImplB is BaseScript, ConfigHelper {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");

        vm.startBroadcast(orderlyPrivateKey);
        LedgerImplB ledgerImplB = new LedgerImplB();
        console.log("new ledgerImplB Address: ", address(ledgerImplB));
        vm.stopBroadcast();

        console.log("All done!");
    }
}

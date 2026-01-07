// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../../src/LedgerImplD.sol";
import "../utils/BaseScript.s.sol";
import "../utils/ConfigHelper.s.sol";

contract DeployNewLedgerImplC is BaseScript, ConfigHelper {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");

        vm.startBroadcast(orderlyPrivateKey);
        LedgerImplD ledgerImplD = new LedgerImplD();
        console.log("new ledgerImplD Address: ", address(ledgerImplD));
        vm.stopBroadcast();

        console.log("All done!");
    }
}
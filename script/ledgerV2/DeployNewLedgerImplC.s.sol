// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../../src/LedgerImplC.sol";
import "../utils/BaseScript.s.sol";
import "../utils/ConfigHelper.s.sol";

contract DeployNewLedgerImplC is BaseScript, ConfigHelper {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");

        vm.startBroadcast(orderlyPrivateKey);
        LedgerImplC ledgerImplC = new LedgerImplC();
        console.log("new ledgerImplC Address: ", address(ledgerImplC));
        vm.stopBroadcast();

        console.log("All done!");
    }
}

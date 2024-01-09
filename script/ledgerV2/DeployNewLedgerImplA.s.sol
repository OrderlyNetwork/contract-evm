// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../../src/LedgerImplA.sol";
import "../utils/BaseScript.s.sol";
import "../utils/ConfigHelper.s.sol";

contract DeployNewLedgerImplA is BaseScript, ConfigHelper {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");

        vm.startBroadcast(orderlyPrivateKey);
        LedgerImplA ledgerImplA = new LedgerImplA();
        console.log("new ledgerImplA Address: ", address(ledgerImplA));
        vm.stopBroadcast();

        console.log("All done!");
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../../src/OperatorManagerImplA.sol";
import "../utils/BaseScript.s.sol";
import "../utils/ConfigHelper.s.sol";

contract DeployNewOperatorManagerImplA is BaseScript, ConfigHelper {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");

        vm.startBroadcast(orderlyPrivateKey);
        OperatorManagerImplA operatorManagerImplA = new OperatorManagerImplA();
        console.log("new operatorManagerImplA Address: ", address(operatorManagerImplA));
        vm.stopBroadcast();

        console.log("All done!");
    }
}

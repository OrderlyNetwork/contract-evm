// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../../src/OperatorManagerImplB.sol";
import "../utils/BaseScript.s.sol";
import "../utils/ConfigHelper.s.sol";

contract DeployNewOperatorManagerImplB is BaseScript, ConfigHelper {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");

        vm.startBroadcast(orderlyPrivateKey);
        OperatorManagerImplB operatorManagerImplB = new OperatorManagerImplB();
        console.log("new operatorManagerImplB Address: ", address(operatorManagerImplB));
        vm.stopBroadcast();

        console.log("All done!");
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import {CREATE3Script} from "./base/CREATE3Script.sol";
import {AssetManager} from "../src/AssetManager.sol";

contract DeployScript is CREATE3Script {
    constructor() CREATE3Script(vm.envString("VERSION")) {}

    function run() external returns (AssetManager a) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        uint256 param = 123;

        vm.startBroadcast(deployerPrivateKey);

        a = AssetManager(
            create3.deploy(
                getCreate3ContractSalt("AssetManager"), bytes.concat(type(AssetManager).creationCode, abi.encode(param))
            )
        );

        vm.stopBroadcast();
    }
}

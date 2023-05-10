// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import {CREATE3Script} from "./base/CREATE3Script.sol";
import {Vault} from "../src/vault.sol";

contract DeployScript is CREATE3Script {
    constructor() CREATE3Script(vm.envString("VERSION")) {}

    function run() external returns (Vault a) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        uint256 param = 123;

        vm.startBroadcast(deployerPrivateKey);

        a = Vault(
            create3.deploy(getCreate3ContractSalt("Vault"), bytes.concat(type(Vault).creationCode, abi.encode(param)))
        );

        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/zip/OperatorManagerZip.sol";
import "../utils/BaseScript.s.sol";
import "../utils/ConfigHelper.s.sol";

contract DeployNewZip is BaseScript, ConfigHelper {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        Envs memory envs = getEnvs();
        string memory env = envs.env;
        string memory network = envs.ledgerNetwork;

        ZipDeployData memory config = getZipDeployData(env, network);
        address zipAddress = config.zip;
        console.log("Zip address: ", zipAddress);

        vm.startBroadcast(orderlyPrivateKey);
        IOperatorManagerZip zipImpl = new OperatorManagerZip();
        console.log("new zip implementation: ", address(zipImpl));
        vm.stopBroadcast();
        console.log("deploy done");
    }
}

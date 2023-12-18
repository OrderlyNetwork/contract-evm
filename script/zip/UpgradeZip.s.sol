// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/zip/OperatorManagerZip.sol";
import "../utils/BaseScript.s.sol";
import "../utils/ConfigHelper.s.sol";

contract UpgradeOperatorManager is BaseScript, ConfigHelper {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        Envs memory envs = getEnvs();
        string memory env = envs.env;
        string memory network = envs.ledgerNetwork;
        LedgerDeployData memory ledgerConfig = getLedgerDeployData(env, network);
        address adminAddress = ledgerConfig.proxyAdmin;

        ZipDeployData memory config = getZipDeployData(env, network);
        address zipAddress = config.zip;
        console.log("adminAddress: ", adminAddress);
        console.log("zip proxy address: ", zipAddress);

        ProxyAdmin admin = ProxyAdmin(adminAddress);
        ITransparentUpgradeableProxy zipProxy = ITransparentUpgradeableProxy(zipAddress);

        vm.startBroadcast(orderlyPrivateKey);

        IOperatorManagerZip zipImpl = new OperatorManagerZip();
        admin.upgrade(zipProxy, address(zipImpl));

        vm.stopBroadcast();
        console.log("upgrade done");
    }
}

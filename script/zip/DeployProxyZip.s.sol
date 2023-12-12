// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/zip/OperatorManagerZip.sol";

import "../utils/BaseScript.s.sol";
import "../utils/ConfigHelper.s.sol";

contract DeployLedger is BaseScript, ConfigHelper {
    string env;
    string network;

    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");

        Envs memory envs = getEnvs();
        env = envs.env;
        network = envs.ledgerNetwork;
        LedgerDeployData memory ledgerConfig = getLedgerDeployData(env, network);
        address operatorManager = ledgerConfig.operatorManager;
        address proxyAdmin = ledgerConfig.proxyAdmin;
        vm.startBroadcast(orderlyPrivateKey);

        ProxyAdmin admin = ProxyAdmin(proxyAdmin);

        // avoid stack too deep error
        {
            console.log("proxyAdmin address: ", address(admin));
        }

        IOperatorManagerZip zipImpl = new OperatorManagerZip();

        bytes memory initData = abi.encodeWithSignature("initialize()");

        TransparentUpgradeableProxy zipProxy =
            new TransparentUpgradeableProxy(address(zipImpl), address(admin), initData);

        // avoid stack too deep error
        {
            console.log("deployed operateManagerZip proxy address: ", address(zipProxy));
            writeZipDeployData(env, network, "zip", vm.toString(address(zipProxy)));
            console.log("deployed success");
        }

        IOperatorManagerZip operatorManagerZip = IOperatorManagerZip(address(zipProxy));

        // avoid stack too deep error
        {
            console.log("operatorManager address: ", operatorManager);
            operatorManagerZip.setOpeartorManager(operatorManager);
            operatorManagerZip.initSymbolId2Hash();
        }
        vm.stopBroadcast();

        console.log("All done!");
    }
}

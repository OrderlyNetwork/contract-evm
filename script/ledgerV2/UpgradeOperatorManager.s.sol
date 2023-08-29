// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/OperatorManager.sol";
import "../utils/BaseScript.s.sol";
import "../utils/ConfigHelper.s.sol";

contract UpgradeOperatorManager is BaseScript, ConfigHelper {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        Envs memory envs = getEnvs();
        string memory env = envs.env;
        string memory network = envs.ledgerNetwork;

        LedgerDepolyData memory config = getLedgerDeployData(env, network);
        address adminAddress = config.proxyAdmin;
        address operatorManagerAddress = config.operatorManager;
        console.log("adminAddress: ", adminAddress);
        console.log("operatorManagerAddress: ", operatorManagerAddress);

        ProxyAdmin admin = ProxyAdmin(adminAddress);
        ITransparentUpgradeableProxy operatorManagerProxy = ITransparentUpgradeableProxy(operatorManagerAddress);

        vm.startBroadcast(orderlyPrivateKey);

        IOperatorManager operatorManagerImpl = new OperatorManager();
        admin.upgrade(operatorManagerProxy, address(operatorManagerImpl));
        // admin.upgradeAndCall(
        //     operatorManagerProxy, address(operatorManagerImpl), abi.encodeWithSignature("initialize()")
        // );

        vm.stopBroadcast();
    }
}

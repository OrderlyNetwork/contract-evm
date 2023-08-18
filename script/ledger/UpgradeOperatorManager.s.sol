// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/OperatorManager.sol";

contract UpgradeOperatorManager is Script {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        address adminAddress = vm.envAddress("LEDGER_PROXY_ADMIN");
        address operatorManagerAddress = vm.envAddress("OPERATOR_MANAGER_ADDRESS");

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

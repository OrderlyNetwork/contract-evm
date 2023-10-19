// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/FeeManager.sol";

contract UpgradeFeeManager is Script {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        address adminAddress = vm.envAddress("LEDGER_PROXY_ADMIN");
        address feeManagerAddress = vm.envAddress("FEE_MANAGER_ADDRESS");

        ProxyAdmin admin = ProxyAdmin(adminAddress);
        ITransparentUpgradeableProxy feeManagerProxy = ITransparentUpgradeableProxy(feeManagerAddress);

        vm.startBroadcast(orderlyPrivateKey);

        IFeeManager feeManagerImpl = new FeeManager();
        admin.upgrade(feeManagerProxy, address(feeManagerImpl));
        // admin.upgradeAndCall(feeManagerProxy, address(feeManagerImpl), abi.encodeWithSignature("initialize()"));

        vm.stopBroadcast();
    }
}

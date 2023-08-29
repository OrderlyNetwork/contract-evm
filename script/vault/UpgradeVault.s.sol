// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/vaultSide/Vault.sol";

contract UpgradeVault is Script {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        address adminAddress = vm.envAddress("VAULT_PROXY_ADMIN");
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");

        ProxyAdmin admin = ProxyAdmin(adminAddress);
        ITransparentUpgradeableProxy vaultProxy = ITransparentUpgradeableProxy(vaultAddress);

        vm.startBroadcast(orderlyPrivateKey);

        IVault vaultImpl = new Vault();
        admin.upgrade(vaultProxy, address(vaultImpl));
        // admin.upgradeAndCall(vaultProxy, address(vaultImpl), abi.encodeWithSignature("initialize()"));

        vm.stopBroadcast();
    }
}

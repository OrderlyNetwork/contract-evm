// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "../../src/vaultSide/Vault.sol";

contract UpgradeVault is Script {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("PK");
        address adminAddress = vm.envAddress("VAULT_PROXY_ADMIN");
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");

        ProxyAdmin admin = ProxyAdmin(adminAddress);
        ITransparentUpgradeableProxy vaultProxy = ITransparentUpgradeableProxy(vaultAddress);

        vm.startBroadcast(orderlyPrivateKey);

        IVault vaultImpl = new Vault();
        // admin.upgrade(vaultProxy, address(vaultImpl));
        // admin.upgradeAndCall(vaultProxy, address(vaultImpl), abi.encodeWithSignature("initialize()"));
        console.log("Vault deployed at:", address(vaultImpl));
        console.log("Vault proxy deployed at:", address(vaultProxy));
        console.log("call: ");
        console.logBytes(abi.encodeWithSelector(OwnableUpgradeable.transferOwnership.selector, adminAddress));

        vm.stopBroadcast();
    }
}

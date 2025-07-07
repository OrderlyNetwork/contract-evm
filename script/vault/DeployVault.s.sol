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

        // ProxyAdmin admin = ProxyAdmin(adminAddress);
        ITransparentUpgradeableProxy vaultProxy = ITransparentUpgradeableProxy(vaultAddress);

        vm.startBroadcast(orderlyPrivateKey);

        IVault vaultImpl = new Vault();
        // admin.upgrade(vaultProxy, address(vaultImpl));
        // admin.upgradeAndCall(vaultProxy, address(vaultImpl), abi.encodeWithSignature("initialize()"));
        // admin.upgradeAndCall(proxy, implementation, data);
        console.log("Vault deployed at:", address(vaultImpl));
        console.log("Vault proxy deployed at:", address(vaultProxy));
        console.log("call: ");
        console.logBytes(abi.encodeWithSelector(OwnableUpgradeable.transferOwnership.selector, adminAddress));
        // 
        bytes32 ethTokenHash = keccak256(abi.encodePacked("ETH"));
        bytes32 usdtTokenHash = keccak256(abi.encodePacked("USDT"));
        bytes32 usdcTokenHash = keccak256(abi.encodePacked("USDC"));

        // print
        console.log("ethTokenHash: ");
        console.logBytes32(ethTokenHash);
        console.log("usdtTokenHash: ");
        console.logBytes32(usdtTokenHash);
        console.log("usdcTokenHash: ");
        console.logBytes32(usdcTokenHash);

        

        vm.stopBroadcast();
    }
}

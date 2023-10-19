// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/vaultSide/Vault.sol";
import "../utils/BaseScript.s.sol";
import "../utils/ConfigHelper.s.sol";

contract UpgradeVault is BaseScript, ConfigHelper {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        Envs memory envs = getEnvs();
        string memory env = envs.env;
        string memory network = envs.vaultNetwork;

        VaultDepolyData memory config = getVaultDeployData(env, network);
        address adminAddress = config.proxyAdmin;
        address vaultAddress = config.vault;
        console.log("adminAddress: ", adminAddress);
        console.log("vaultAddress: ", vaultAddress);

        ProxyAdmin admin = ProxyAdmin(adminAddress);
        ITransparentUpgradeableProxy vaultProxy = ITransparentUpgradeableProxy(vaultAddress);

        vm.startBroadcast(orderlyPrivateKey);

        IVault vaultImpl = new Vault();
        admin.upgrade(vaultProxy, address(vaultImpl));

        vm.stopBroadcast();
        console.log("upgrade done");
    }
}

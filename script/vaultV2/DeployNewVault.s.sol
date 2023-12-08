// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/vaultSide/Vault.sol";
import "../utils/BaseScript.s.sol";
import "../utils/ConfigHelper.s.sol";

contract DeployNewVault is BaseScript, ConfigHelper {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        Envs memory envs = getEnvs();
        string memory env = envs.env;
        string memory network = envs.vaultNetwork;

        VaultDeployData memory config = getVaultDeployData(env, network);
        address vaultAddress = config.vault;
        console.log("vaultAddress: ", vaultAddress);

        vm.startBroadcast(orderlyPrivateKey);
        IVault vaultImpl = new Vault();
        console.log("new vaultImplAddress: ", address(vaultImpl));
        vm.stopBroadcast();
        console.log("deploy done");
    }
}

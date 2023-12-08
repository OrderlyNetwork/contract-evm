// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../../src/vaultSide/Vault.sol";
import "../utils/BaseScript.s.sol";
import "../utils/ConfigHelper.s.sol";

contract VaultSetCrossChainManager is BaseScript, ConfigHelper {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        address vaultCrossChainManagerAddress = vm.envAddress("VAULT_CROSS_CHAIN_MANAGER_ADDRESS"); // FIXME
        Envs memory envs = getEnvs();
        string memory env = envs.env;
        string memory network = envs.vaultNetwork;

        VaultDeployData memory config = getVaultDeployData(env, network);
        address adminAddress = config.proxyAdmin;
        address vaultAddress = config.vault;
        console.log("adminAddress: ", adminAddress);
        console.log("vaultAddress: ", vaultAddress);

        vm.startBroadcast(orderlyPrivateKey);

        IVault vault = Vault(vaultAddress);
        vault.setCrossChainManager(vaultCrossChainManagerAddress);

        vm.stopBroadcast();
        console.log("setCrossChainManager done");
    }
}

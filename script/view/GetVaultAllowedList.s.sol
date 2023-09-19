// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/vaultSide/Vault.sol";
import "../utils/BaseScript.s.sol";
import "../utils/ConfigHelper.s.sol";

contract GetVaultAllowedList is BaseScript, ConfigHelper {
    function run() external {
        Envs memory envs = getEnvs();
        string memory env = envs.env;
        string memory network = envs.vaultNetwork;
        console.log("env: ", env);
        console.log("network: ", network);

        VaultDepolyData memory config = getVaultDeployData(env, network);
        address vaulAddress = config.vault;
        console.log("vaultAddress: ", vaulAddress);
        IVault vault = IVault(vaulAddress);
        // brokerId
        bytes32[] memory allAllowedBroker = vault.getAllAllowedBroker();
        console2.log("allAllowedBroker length: ", allAllowedBroker.length);
        for (uint256 i = 0; i < allAllowedBroker.length; i++) {
            console2.logBytes32(allAllowedBroker[i]);
        }
        // token
        bytes32[] memory allAllowedToken = vault.getAllAllowedToken();
        console2.log("allAllowedToken length: ", allAllowedToken.length);
        for (uint256 i = 0; i < allAllowedToken.length; i++) {
            console2.logBytes32(allAllowedToken[i]);
        }
        console.log("get allowed list done");
    }
}

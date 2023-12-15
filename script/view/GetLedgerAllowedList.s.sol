// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/VaultManager.sol";
import "../utils/BaseScript.s.sol";
import "../utils/ConfigHelper.s.sol";

contract GetLedgerAllowedList is BaseScript, ConfigHelper {
    function run() external {
        Envs memory envs = getEnvs();
        string memory env = envs.env;
        string memory network = envs.ledgerNetwork;
        console.log("env: ", env);
        console.log("network: ", network);

        LedgerDeployData memory config = getLedgerDeployData(env, network);
        address vaultManagerAddress = config.vaultManager;
        console.log("vaultManagerAddress: ", vaultManagerAddress);
        IVaultManager vaultManager = IVaultManager(vaultManagerAddress);
        // brokerId
        bytes32[] memory allAllowedBroker = vaultManager.getAllAllowedBroker();
        console2.log("allAllowedBroker length: ", allAllowedBroker.length);
        for (uint256 i = 0; i < allAllowedBroker.length; i++) {
            console2.logBytes32(allAllowedBroker[i]);
        }
        // token
        bytes32[] memory allAllowedToken = vaultManager.getAllAllowedToken();
        console2.log("allAllowedToken length: ", allAllowedToken.length);
        for (uint256 i = 0; i < allAllowedToken.length; i++) {
            console2.logBytes32(allAllowedToken[i]);
        }
        // symbol
        bytes32[] memory allAllowedSymbol = vaultManager.getAllAllowedSymbol();
        console2.log("allAllowedSymbol length: ", allAllowedSymbol.length);
        for (uint256 i = 0; i < allAllowedSymbol.length; i++) {
            console2.logBytes32(allAllowedSymbol[i]);
        }
        console.log("get allowed list done");
    }
}

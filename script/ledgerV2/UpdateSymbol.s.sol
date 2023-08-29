// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/VaultManager.sol";
import "../utils/BaseScript.s.sol";
import "../utils/ConfigHelper.s.sol";

contract UpdateSymbol is BaseScript, ConfigHelper {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");

        Envs memory envs = getEnvs();
        string memory env = envs.env;
        string memory network = envs.ledgerNetwork;
        console.log("env: ", env);
        console.log("network: ", network);

        LedgerDepolyData memory config = getLedgerDeployData(env, network);
        address adminAddress = config.proxyAdmin;
        address vaultManagerAddress = config.vaultManager;
        console.log("adminAddress: ", adminAddress);
        console.log("vaultManagerAddress: ", vaultManagerAddress);

        vm.startBroadcast(orderlyPrivateKey);

        IVaultManager vaultManager = IVaultManager(vaultManagerAddress);
        vaultManager.setAllowedSymbol(0x5a8133e52befca724670dbf2cade550c522c2410dd5b1189df675e99388f509d, true); // PERP_BTC_USDC
        vaultManager.setAllowedSymbol(0x5d0471b083610a6f3b572fc8b0f759c5628e74159816681fb7d927b9263de60b, true); // PERP_WOO_USDC

        vm.stopBroadcast();
    }
}

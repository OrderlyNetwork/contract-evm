// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/VaultManager.sol";
import "../utils/BaseScript.s.sol";
import "../utils/ConfigHelper.s.sol";

contract DeployNewVaultManager is BaseScript, ConfigHelper {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        Envs memory envs = getEnvs();
        string memory env = envs.env;
        string memory network = envs.ledgerNetwork;

        LedgerDeployData memory config = getLedgerDeployData(env, network);
        address vaultManagerAddress = config.vaultManager;
        console.log("vaultManagerAddress: ", vaultManagerAddress);

        vm.startBroadcast(orderlyPrivateKey);
        IVaultManager vaultManagerImpl = new VaultManager();
        console.log("new vaultManagerImplAddress: ", address(vaultManagerImpl));
        vm.stopBroadcast();
        console.log("deploy done");
    }
}

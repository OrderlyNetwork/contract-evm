// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/vaultSide/Vault.sol";
import "../utils/BaseScript.s.sol";
import "../utils/ConfigHelper.s.sol";

contract TransferOwner is BaseScript, ConfigHelper {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        Envs memory envs = getEnvs();
        string memory env = envs.env;
        string memory network = envs.vaultNetwork;

        VaultDeployData memory config = getVaultDeployData(env, network);
        address adminAddress = config.proxyAdmin;
        address vaultAddress = config.vault;
        address multiSigAddress = config.multiSig;
        console.log("adminAddress: ", adminAddress);
        console.log("vaultAddress: ", vaultAddress);
        console.log("multiSigAddress: ", multiSigAddress);

        vm.startBroadcast(orderlyPrivateKey);

        {
            // first change the owner of the impls
            Vault vault = Vault(vaultAddress);
            vault.transferOwnership(multiSigAddress);
        }

        {
            // second change the owner of the ProxyAdmin
            ProxyAdmin admin = ProxyAdmin(adminAddress);
            admin.transferOwnership(multiSigAddress);
        }

        vm.stopBroadcast();
        console.log("transfer owner done");
    }
}

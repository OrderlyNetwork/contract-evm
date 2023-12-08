// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/vaultSide/Vault.sol";
import "../utils/BaseScript.s.sol";
import "../utils/ConfigHelper.s.sol";

contract DeployVault is BaseScript, ConfigHelper {
    bytes32 constant USDC = 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa;
    bytes32 constant BROKER_HASH = 0x6ca2f644ef7bd6d75953318c7f2580014941e753b3c6d54da56b3bf75dd14dfc; // woofi_pro
    bytes32 constant BROKER_HASH2 = 0xd6c66cad06fe14fdb6ce9297d80d32f24d7428996d0045cbf90cc345c677ba16; // root
    bytes32 constant BROKER_HASH3 = 0x95d85ced8adb371760e4b6437896a075632fbd6cefe699f8125a8bc1d9b19e5b; // orderly

    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        Envs memory envs = getEnvs();
        string memory env = envs.env;
        string memory network = envs.vaultNetwork;

        VaultDeployData memory config = getVaultDeployData(env, network);
        address usdcAddress = config.usdc;
        console.log("usdcAddress: ", usdcAddress);

        vm.startBroadcast(orderlyPrivateKey);

        ProxyAdmin admin = new ProxyAdmin();

        IVault vaultImpl = new Vault();
        TransparentUpgradeableProxy vaultProxy =
            new TransparentUpgradeableProxy(address(vaultImpl), address(admin), abi.encodeWithSignature("initialize()"));
        IVault vault = IVault(address(vaultProxy));

        // avoid stack too deep error
        {
            console.log("deployed proxyAdmin address: ", address(admin));
            console.log("deployed vault proxy address: ", address(vaultProxy));
            writeVaultDeployData(env, network, "proxyAdmin", vm.toString(address(admin)));
            writeVaultDeployData(env, network, "vault", vm.toString(address(vaultProxy)));
        }

        vault.changeTokenAddressAndAllow(USDC, usdcAddress);
        vault.setAllowedBroker(BROKER_HASH, true);
        vault.setAllowedBroker(BROKER_HASH2, true);
        vault.setAllowedBroker(BROKER_HASH3, true);

        vm.stopBroadcast();
        console.log("All done!");
    }
}

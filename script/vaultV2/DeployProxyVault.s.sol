// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/vaultSide/Vault.sol";
import "../../src/vaultSide/tUSDC.sol";
import "../utils/BaseScript.s.sol";
import "../utils/ConfigHelper.s.sol";

contract DeployVault is BaseScript, ConfigHelper {
    bytes32 constant USDC = 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa;
    bytes32 constant BROKER_HASH = 0x083098c593f395bea1de45dda552d9f14e8fcb0be3faaa7a1903c5477d7ba7fd; // woofi_dex

    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        Envs memory envs = getEnvs();
        string memory env = envs.env;
        string memory network = envs.vaultNetwork;

        VaultDepolyData memory config = getVaultDeployData(env, network);
        address usdcAddress = config.tUSDC;
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

        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../../src/Vault.sol";
import "../../src/testUSDC/tUSDC.sol";

contract DeployVault is Script {
    bytes32 constant USDC = 0x61fc29e9a6b4b52b423e75ca44734454f94ea60ddff3dc47af01a2a646fe9572;
    bytes32 constant BROKER_HASH = 0xfb08c0b22085b07c3787ca55e02cc585a966b0799bfef3d32fc335d7107cedef;

    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        address vaultCrossChainManagerAddress = vm.envAddress("VAULT_CROSS_CHAIN_MANAGER_ADDRESS");
        vm.startBroadcast(orderlyPrivateKey);

        IVaultCrossChainManager vaultCrossChainManager = IVaultCrossChainManager(payable(vaultCrossChainManagerAddress));

        IVault vault = new Vault();
        TestUSDC tUSDC = new TestUSDC();
        vault.addToken(USDC, address(tUSDC));
        vault.addBroker(BROKER_HASH);
        vault.setCrossChainManager(address(vaultCrossChainManager));

        vaultCrossChainManager.setVault(address(vault));

        vm.stopBroadcast();
    }
}

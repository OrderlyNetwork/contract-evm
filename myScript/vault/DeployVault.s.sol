// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../../src/Vault.sol";
import "../../src/testUSDC/tUSDC.sol";

contract DeployVault is Script {
    bytes32 constant USDC = 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa;
    bytes32 constant BROKER_HASH = 0x083098c593f395bea1de45dda552d9f14e8fcb0be3faaa7a1903c5477d7ba7fd;

    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        address vaultCrossChainManagerAddress = vm.envAddress("VAULT_CROSS_CHAIN_MANAGER_ADDRESS");
        vm.startBroadcast(orderlyPrivateKey);

        IVaultCrossChainManager vaultCrossChainManager = IVaultCrossChainManager(payable(vaultCrossChainManagerAddress));

        IVault vault = new Vault();
        TestUSDC tUSDC = new TestUSDC();
        vault.setAllowedToken(USDC, address(tUSDC));
        vault.setAllowedBroker(BROKER_HASH, true);
        vault.setCrossChainManager(address(vaultCrossChainManager));

        vaultCrossChainManager.setVault(address(vault));

        vm.stopBroadcast();
    }
}

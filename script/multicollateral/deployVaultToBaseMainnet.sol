// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../test/multicollateral/vaultReceiveEth.sol";
import "../../src/vaultSide/Vault.sol";
import "../../src/vaultSide/tUSDC.sol";

contract DeployVault is Script {
    bytes32 constant USDC = 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa;
    bytes32 constant USDT = 0x8b1a1d9c2b109e527c9134b25b1a1833b16b6594f92daa9f6d9b7a6024bce9d0;
    bytes32 constant ETH = 0xaaaebeba3810b1e6b70781f14b2d72c1cb89c0b2b320c43bb67ff79f562f5ff4;
    bytes32 constant BROKER_HASH = 0x083098c593f395bea1de45dda552d9f14e8fcb0be3faaa7a1903c5477d7ba7fd;
    address constant USDC_ADDRESS = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant USDT_ADDRESS = 0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2;
    // address constant SWAP_OPERATOR = 0x963c6dF1477a2C8153DF0636Be95f506A4A1B06C;
    address constant SWAP_OPERATOR = 0x2d4e9C592b9f42557DAE7B103F3fCA47448DC0BD;
    address constant PROXY_ADMIN = 0xBdbf4c04e0E137dC385c66e99793ab9B3ABa72e2;

    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("PROD_PK");

        vm.startBroadcast(orderlyPrivateKey);

        // ProxyAdmin admin = new ProxyAdmin();
        address admin = PROXY_ADMIN;

        IVault vaultImpl = new VaultReceiveEth();
        TransparentUpgradeableProxy vaultProxy =
            new TransparentUpgradeableProxy(address(vaultImpl), address(admin), abi.encodeWithSignature("initialize()"));
        IVault vault = IVault(address(vaultProxy));

        vault.changeTokenAddressAndAllow(USDC, USDC_ADDRESS);
        vault.changeTokenAddressAndAllow(USDT, USDT_ADDRESS);
        vault.setNativeTokenHash(ETH);
        vault.setAllowedToken(ETH, true);
        vault.setAllowedBroker(BROKER_HASH, true);
        vault.setSwapOperator(SWAP_OPERATOR);
        vault.setSwapSigner(SWAP_OPERATOR);
        // vault.setCrossChainManager(address(vaultCrossChainManager));

        // vaultCrossChainManager.setVault(address(vault));

        vm.stopBroadcast();
    }
}

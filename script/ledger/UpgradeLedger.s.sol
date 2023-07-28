// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/Ledger.sol";

contract UpgradeLedger is Script {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        address adminAddress = vm.envAddress("LEDGER_PROXY_ADMIN");
        address ledgerAddress = vm.envAddress("LEDGER_ADDRESS");

        ProxyAdmin admin = ProxyAdmin(adminAddress);
        ITransparentUpgradeableProxy ledgerProxy = ITransparentUpgradeableProxy(ledgerAddress);

        vm.startBroadcast(orderlyPrivateKey);

        ILedger ledgerImpl = new Ledger();
        admin.upgradeAndCall(ledgerProxy, address(ledgerImpl), abi.encodeWithSignature("upgradeInit()"));

        vm.stopBroadcast();
    }
}

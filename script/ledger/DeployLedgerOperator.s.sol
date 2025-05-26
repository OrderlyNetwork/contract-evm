// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/Ledger.sol";
import "../../src/LedgerImplA.sol";
import "../../src/LedgerImplB.sol";
import "../../src/LedgerImplC.sol";
import "../../src/LedgerImplD.sol";
import "../../src/OperatorManager.sol";
import "../../src/OperatorManagerImplA.sol";
import "../../src/OperatorManagerImplB.sol";

contract DeployLedger is Script {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("PK");
        // address adminAddress = vm.envAddress("LEDGER_PROXY_ADMIN");
        // address ledgerAddress = vm.envAddress("LEDGER_ADDRESS");

        // ProxyAdmin admin = ProxyAdmin(adminAddress);
        // ITransparentUpgradeableProxy ledgerProxy = ITransparentUpgradeableProxy(ledgerAddress);

        vm.startBroadcast(orderlyPrivateKey);

        Ledger ledger = new Ledger();
        LedgerImplA ledgerImplA = new LedgerImplA();
        LedgerImplB ledgerImplB = new LedgerImplB();
        LedgerImplC ledgerImplC = new LedgerImplC();
        LedgerImplD ledgerImplD = new LedgerImplD();

        OperatorManager operatorManager = new OperatorManager();
        OperatorManagerImplA operatorManagerImplA = new OperatorManagerImplA();
        OperatorManagerImplB operatorManagerImplB = new OperatorManagerImplB();

        console.log("ledger: ", address(ledger));
        console.log("ledgerImplA: ", address(ledgerImplA));
        console.log("ledgerImplB: ", address(ledgerImplB));
        console.log("ledgerImplC: ", address(ledgerImplC));
        console.log("ledgerImplD: ", address(ledgerImplD));
        console.log("operatorManager: ", address(operatorManager));
        console.log("operatorManagerImplA: ", address(operatorManagerImplA));
        console.log("operatorManagerImplB: ", address(operatorManagerImplB));
        // admin.upgrade(ledgerProxy, address(ledgerImpl));
        // admin.upgradeAndCall(ledgerProxy, address(ledgerImpl), abi.encodeWithSignature("initialize()"));

        vm.stopBroadcast();
    }
}

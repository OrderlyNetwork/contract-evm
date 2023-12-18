// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../src/OperatorManager.sol";
import "../src/Ledger.sol";
import "../src/VaultManager.sol";
import "./mock/LedgerCrossChainManagerMock.sol";

contract OperatorManagerTest is Test {
    ProxyAdmin admin;
    address constant operatorAddress = address(0x1234567890);
    ILedgerCrossChainManager ledgerCrossChainManager;
    IOperatorManager operatorManager;
    IVaultManager vaultManager;
    ILedger ledger;
    TransparentUpgradeableProxy operatorProxy;
    TransparentUpgradeableProxy vaultProxy;
    TransparentUpgradeableProxy ledgerProxy;

    function setUp() public {
        admin = new ProxyAdmin();

        ledgerCrossChainManager = new LedgerCrossChainManagerMock();
        IOperatorManager operatorManagerImpl = new OperatorManager();
        IVaultManager vaultManagerImpl = new VaultManager();
        ILedger ledgerImpl = new Ledger();

        operatorProxy = new TransparentUpgradeableProxy(address(operatorManagerImpl), address(admin), "");
        vaultProxy = new TransparentUpgradeableProxy(address(vaultManagerImpl), address(admin), "");
        ledgerProxy = new TransparentUpgradeableProxy(address(ledgerImpl), address(admin), "");

        operatorManager = IOperatorManager(address(operatorProxy));
        vaultManager = IVaultManager(address(vaultProxy));
        ledger = ILedger(address(ledgerProxy));

        operatorManager.initialize();
        vaultManager.initialize();
        ledger.initialize();

        ledger.setOperatorManagerAddress(address(operatorManager));
        ledger.setCrossChainManager(address(ledgerCrossChainManager));
        ledger.setVaultManager(address(vaultManager));

        operatorManager.setOperator(operatorAddress);
        operatorManager.setLedger(address(ledger));

        ledgerCrossChainManager.setLedger(address(ledger));
        ledgerCrossChainManager.setOperatorManager(address(operatorManager));

        vaultManager.setLedgerAddress(address(ledger));
    }

    function test_ping() public {
        vm.prank(operatorAddress);
        operatorManager.operatorPing();
    }

    function testRevert_pingNotOperator() public {
        vm.prank(address(0x1));
        vm.expectRevert(IError.OnlyOperatorCanCall.selector);
        operatorManager.operatorPing();
    }

    function test_engineNotDown() public {
        bool isDown = operatorManager.checkEngineDown();
        assertEq(isDown, false);
    }
}

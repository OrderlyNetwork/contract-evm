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
    OperatorManager operatorManager;
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

        operatorManager = OperatorManager(address(operatorProxy));
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

    // function selectors on Ledger contract: https://testnet-explorer.orderly.org/address/0x8794E7260517B1766fc7b55cAfcd56e6bf08600e?tab=write_proxy
    function test_biztype_selector() public {
        operatorManager.initBizTypeToSelector();
        assertTrue(operatorManager.bizTypeToSelectors(1) == 0x965a1cba);    // executeWithdrawAction
        assertTrue(operatorManager.bizTypeToSelectors(2) == 0x7c6c3bd5);    // executeSettlement
        assertTrue(operatorManager.bizTypeToSelectors(3) == 0xc61ca104);    // executeAdl   
        assertTrue(operatorManager.bizTypeToSelectors(4) == 0x619fa7fe);    // executeLiquidation   
        assertTrue(operatorManager.bizTypeToSelectors(5) == 0x9078ffd8);    // executeFeeDistribution
        assertTrue(operatorManager.bizTypeToSelectors(6) == 0x0997c228);    // executeDelegateSigner
        assertTrue(operatorManager.bizTypeToSelectors(7) == 0xec0a14aa);    // executeDelegateWithdrawAction
        assertTrue(operatorManager.bizTypeToSelectors(8) == 0xf97a259c);    // executeAdlV2
        assertTrue(operatorManager.bizTypeToSelectors(9) == 0xb8375d1f);    // executeLiquidationV2
        assertTrue(operatorManager.bizTypeToSelectors(10) == 0xd2050cb5);   // executeWithdrawSolAction
        assertTrue(operatorManager.bizTypeToSelectors(11) == 0xa71e351f);   // executeWithdraw2Contract
        assertTrue(operatorManager.bizTypeToSelectors(12) == 0xf83bd887);   // executeBalanceTransfer
        assertTrue(operatorManager.bizTypeToSelectors(13) == 0xae5f766e);   // executeSwapResultUpload
        assertTrue(operatorManager.bizTypeToSelectors(14) == 0x9df6d026);   // executeWithdraw2ContractV2

    }
        
}

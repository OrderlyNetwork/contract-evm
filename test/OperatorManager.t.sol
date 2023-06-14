// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/OperatorManager.sol";
import "../src/Ledger.sol";
import "../src/VaultManager.sol";
import "./mock/LedgerCrossChainManagerMock.sol";

contract OperatorManagerTest is Test {
    address constant operatorAddress = address(0x1234567890);
    ILedgerCrossChainManager ledgerCrossChainManager;
    IOperatorManager operatorManager;
    IVaultManager vaultManager;
    ILedger ledger;

    function setUp() public {
        ledgerCrossChainManager = new LedgerCrossChainManagerMock();
        operatorManager = new OperatorManager();
        vaultManager = new VaultManager();
        ledger = new Ledger();

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

    function testFail_pingNotOperator() public {
        vm.prank(address(0x1));
        operatorManager.operatorPing();
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../src/VaultManager.sol";
import "../src/Ledger.sol";

contract VaultManagerTest is Test {
    ProxyAdmin admin;
    IVaultManager vaultManager;
    ILedger ledger;
    TransparentUpgradeableProxy vaultManagerProxy;
    TransparentUpgradeableProxy ledgerManagerProxy;
    uint256 constant CHAIN_ID = 0xabcd;
    bytes32 constant TOKEN_HASH = 0x61fc29e9a6b4b52b423e75ca44734454f94ea60ddff3dc47af01a2a646fe9572;
    bytes32 constant BROKER_HASH = 0x083098c593f395bea1de45dda552d9f14e8fcb0be3faaa7a1903c5477d7ba7fd;
    bytes32 constant SYMBOL_HASH = 0xa2adc016e890b4fbbf161c7eaeb615b893e4fbeceae918fa7bf16cc40d46610b;

    function setUp() public {
        admin = new ProxyAdmin();

        IVaultManager vaultManagerImpl = new VaultManager();
        ILedger ledgerImpl = new Ledger();

        vaultManagerProxy = new TransparentUpgradeableProxy(address(vaultManagerImpl), address(admin), "");
        ledgerManagerProxy = new TransparentUpgradeableProxy(address(ledgerImpl), address(admin), "");

        vaultManager = IVaultManager(address(vaultManagerProxy));
        ledger = ILedger(address(ledgerManagerProxy));

        vaultManager.initialize();
        ledger.initialize();

        vaultManager.setLedgerAddress(address(ledger));
        ledger.setVaultManager(address(vaultManager));
    }

    function test_sub_add_get() public {
        vm.startPrank(address(ledger));
        vaultManager.addBalance(TOKEN_HASH, CHAIN_ID, 100);
        assertEq(vaultManager.getBalance(TOKEN_HASH, CHAIN_ID), 100);
        vaultManager.addBalance(TOKEN_HASH, CHAIN_ID, 200);
        assertEq(vaultManager.getBalance(TOKEN_HASH, CHAIN_ID), 300);
        vaultManager.subBalance(TOKEN_HASH, CHAIN_ID, 150);
        assertEq(vaultManager.getBalance(TOKEN_HASH, CHAIN_ID), 150);
        vm.stopPrank();
    }

    function testFail_sub_overflow() public {
        vm.startPrank(address(ledger));
        vaultManager.addBalance(TOKEN_HASH, CHAIN_ID, 100);
        assertEq(vaultManager.getBalance(TOKEN_HASH, CHAIN_ID), 100);
        vaultManager.subBalance(TOKEN_HASH, CHAIN_ID, 150);
        vm.stopPrank();
    }

    function test_frozen_finish_frozen() public {
        vm.startPrank(address(ledger));
        vaultManager.addBalance(TOKEN_HASH, CHAIN_ID, 300);
        assertEq(vaultManager.getBalance(TOKEN_HASH, CHAIN_ID), 300);
        vaultManager.frozenBalance(TOKEN_HASH, CHAIN_ID, 200);
        assertEq(vaultManager.getBalance(TOKEN_HASH, CHAIN_ID), 100);
        assertEq(vaultManager.getFrozenBalance(TOKEN_HASH, CHAIN_ID), 200);
        vaultManager.finishFrozenBalance(TOKEN_HASH, CHAIN_ID, 200);
        assertEq(vaultManager.getBalance(TOKEN_HASH, CHAIN_ID), 100);
        assertEq(vaultManager.getFrozenBalance(TOKEN_HASH, CHAIN_ID), 0);
        vm.stopPrank();
    }

    function test_frozen_finish_frozen_zero() public {
        vm.startPrank(address(ledger));
        vaultManager.addBalance(TOKEN_HASH, CHAIN_ID, 300);
        assertEq(vaultManager.getBalance(TOKEN_HASH, CHAIN_ID), 300);
        vaultManager.frozenBalance(TOKEN_HASH, CHAIN_ID, 200);
        assertEq(vaultManager.getBalance(TOKEN_HASH, CHAIN_ID), 100);
        assertEq(vaultManager.getFrozenBalance(TOKEN_HASH, CHAIN_ID), 200);
        vaultManager.finishFrozenBalance(TOKEN_HASH, CHAIN_ID, 200);
        assertEq(vaultManager.getBalance(TOKEN_HASH, CHAIN_ID), 100);
        assertEq(vaultManager.getFrozenBalance(TOKEN_HASH, CHAIN_ID), 0);
        vaultManager.frozenBalance(TOKEN_HASH, CHAIN_ID, 100);
        assertEq(vaultManager.getBalance(TOKEN_HASH, CHAIN_ID), 0);
        assertEq(vaultManager.getFrozenBalance(TOKEN_HASH, CHAIN_ID), 100);
        vaultManager.finishFrozenBalance(TOKEN_HASH, CHAIN_ID, 100);
        assertEq(vaultManager.getBalance(TOKEN_HASH, CHAIN_ID), 0);
        assertEq(vaultManager.getFrozenBalance(TOKEN_HASH, CHAIN_ID), 0);
        vm.stopPrank();
    }

    function testFail_frozen_overflow_1() public {
        vm.startPrank(address(ledger));
        vaultManager.addBalance(TOKEN_HASH, CHAIN_ID, 100);
        assertEq(vaultManager.getBalance(TOKEN_HASH, CHAIN_ID), 100);
        vaultManager.frozenBalance(TOKEN_HASH, CHAIN_ID, 150);
        vm.stopPrank();
    }

    function testFail_frozen_overflow_2() public {
        vm.startPrank(address(ledger));
        vaultManager.addBalance(TOKEN_HASH, CHAIN_ID, 200);
        assertEq(vaultManager.getBalance(TOKEN_HASH, CHAIN_ID), 200);
        vaultManager.subBalance(TOKEN_HASH, CHAIN_ID, 100);
        assertEq(vaultManager.getBalance(TOKEN_HASH, CHAIN_ID), 100);
        vaultManager.frozenBalance(TOKEN_HASH, CHAIN_ID, 150);
        vm.stopPrank();
    }

    function test_getAllWhitelistSet() public {
        vaultManager.setAllowedChainToken(TOKEN_HASH, CHAIN_ID, true);
        vaultManager.setAllowedToken(TOKEN_HASH, true);
        vaultManager.setAllowedBroker(BROKER_HASH, true);
        vaultManager.setAllowedSymbol(SYMBOL_HASH, true);
        assertEq(vaultManager.getAllAllowedBroker().length, 1);
        assertEq(vaultManager.getAllAllowedToken().length, 1);
        assertEq(vaultManager.getAllAllowedSymbol().length, 1);
    }

    function test_setThenUnsetWhitelist() public {
        vaultManager.setAllowedChainToken(TOKEN_HASH, CHAIN_ID, true);
        vaultManager.setAllowedToken(TOKEN_HASH, true);
        vaultManager.setAllowedBroker(BROKER_HASH, true);
        vaultManager.setAllowedSymbol(SYMBOL_HASH, true);
        assertTrue(vaultManager.getAllowedBroker(BROKER_HASH));
        assertTrue(vaultManager.getAllowedToken(TOKEN_HASH));
        assertTrue(vaultManager.getAllowedSymbol(SYMBOL_HASH));
        vaultManager.setAllowedChainToken(TOKEN_HASH, CHAIN_ID, false);
        vaultManager.setAllowedToken(TOKEN_HASH, false);
        vaultManager.setAllowedBroker(BROKER_HASH, false);
        vaultManager.setAllowedSymbol(SYMBOL_HASH, false);
        assertFalse(vaultManager.getAllowedBroker(BROKER_HASH));
        assertFalse(vaultManager.getAllowedToken(TOKEN_HASH));
        assertFalse(vaultManager.getAllowedSymbol(SYMBOL_HASH));
    }

    function test_chainTokenAllowance() public {
        vaultManager.setAllowedChainToken(TOKEN_HASH, CHAIN_ID, true);
        vaultManager.setAllowedToken(TOKEN_HASH, true);
        assertTrue(vaultManager.getAllowedChainToken(TOKEN_HASH, CHAIN_ID));
        assertTrue(vaultManager.getAllowedToken(TOKEN_HASH));
        vaultManager.setAllowedChainToken(TOKEN_HASH, CHAIN_ID, false);
        vaultManager.setAllowedToken(TOKEN_HASH, true);
        assertFalse(vaultManager.getAllowedChainToken(TOKEN_HASH, CHAIN_ID));
        assertTrue(vaultManager.getAllowedToken(TOKEN_HASH));
        vaultManager.setAllowedChainToken(TOKEN_HASH, CHAIN_ID, true);
        vaultManager.setAllowedToken(TOKEN_HASH, false);
        assertFalse(vaultManager.getAllowedChainToken(TOKEN_HASH, CHAIN_ID));
        assertFalse(vaultManager.getAllowedToken(TOKEN_HASH));
    }
}

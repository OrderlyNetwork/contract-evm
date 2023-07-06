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
}

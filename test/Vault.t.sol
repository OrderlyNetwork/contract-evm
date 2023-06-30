// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Vault.sol";
import "../src/testUSDC/tUSDC.sol";
import "./mock/VaultCrossChainManagerMock.sol";

contract VaultTest is Test {
    IVaultCrossChainManager vaultCrossChainManager;
    TestUSDC tUSDC;
    IVault vault;
    uint128 constant AMOUNT = 1000000;
    address constant SENDER = 0x4FDDB51ADe1fa66952de254bE7E1a84EEB153331;
    bytes32 constant ACCOUNT_ID = 0x89bf2019fe60f13ec6c3f8de8c10156c2691ba5e743260dbcd81c2c66e87cba0;
    bytes32 constant BROKER_HASH = 0x083098c593f395bea1de45dda552d9f14e8fcb0be3faaa7a1903c5477d7ba7fd;  // woofi_dex
    bytes32 constant TOKEN_HASH = 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa;   // USDC
    VaultTypes.VaultDepositFE depositData = VaultTypes.VaultDepositFE({
        accountId: ACCOUNT_ID,
        brokerHash: BROKER_HASH,
        tokenHash: TOKEN_HASH,
        tokenAmount: AMOUNT
    });
    VaultTypes.VaultWithdraw withdrawData = VaultTypes.VaultWithdraw({
        accountId: ACCOUNT_ID,
        sender: SENDER,
        receiver: SENDER,
        brokerHash: BROKER_HASH,
        tokenHash: TOKEN_HASH,
        tokenAmount: AMOUNT,
        fee: 0,
        withdrawNonce: 0
    });

    function setUp() public {
        tUSDC = new TestUSDC();
        vault = new Vault();
        vault.addToken(TOKEN_HASH, address(tUSDC));
        vault.addBroker(BROKER_HASH);
        vaultCrossChainManager = new VaultCrossChainManagerMock();
        vault.setCrossChainManager(address(vaultCrossChainManager));
    }

    function test_deposit() public {
        vm.startPrank(SENDER);
        tUSDC.mint(SENDER, AMOUNT);
        tUSDC.approve(address(vault), AMOUNT);
        assertEq(tUSDC.balanceOf(address(SENDER)), AMOUNT);

        vault.deposit(depositData);
        vm.stopPrank();
        assertEq(tUSDC.balanceOf(address(SENDER)), 0);
        assertEq(tUSDC.balanceOf(address(vault)), AMOUNT);
    }

    function test_withdraw() public {
        vm.startPrank(SENDER);
        tUSDC.mint(SENDER, AMOUNT);
        tUSDC.approve(address(vault), AMOUNT);
        vault.deposit(depositData);
        vm.stopPrank();

        vm.prank(address(vaultCrossChainManager));
        vault.withdraw(withdrawData);
        assertEq(tUSDC.balanceOf(address(SENDER)), AMOUNT);
        assertEq(tUSDC.balanceOf(address(vault)), 0);
    }
}

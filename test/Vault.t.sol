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
    uint256 constant AMOUNT = 1000000;
    address constant SENDER = 0x4FDDB51ADe1fa66952de254bE7E1a84EEB153331;
    bytes32 constant ACCOUNT_ID = 0x1794513e2fc05828d3205892dbef3c91eb7ffd6df62e0360acadd55650c9b672;
    bytes32 constant BROKER_HASH = 0xfb08c0b22085b07c3787ca55e02cc585a966b0799bfef3d32fc335d7107cedef;
    bytes32 constant TOKEN_HASH = 0x61fc29e9a6b4b52b423e75ca44734454f94ea60ddff3dc47af01a2a646fe9572;
    VaultTypes.VaultDepositFE depositData =
        VaultTypes.VaultDepositFE({
            accountId: ACCOUNT_ID,
            brokerHash: BROKER_HASH,
            tokenHash: TOKEN_HASH,
            tokenAmount: AMOUNT
        });
    VaultTypes.VaultWithdraw withdrawData =
        VaultTypes.VaultWithdraw({
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
        vault = new Vault(address(tUSDC));
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
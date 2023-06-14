// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/OperatorManager.sol";
import "../src/Ledger.sol";
import "../src/VaultManager.sol";
import "./mock/LedgerCrossChainManagerMock.sol";

contract LedgerTest is Test {
    address constant operatorAddress = address(0x1234567890);
    ILedgerCrossChainManager ledgerCrossChainManager;
    IOperatorManager operatorManager;
    IVaultManager vaultManager;
    ILedger ledger;

    uint256 constant AMOUNT = 1000000;
    address constant SENDER = 0x4FDDB51ADe1fa66952de254bE7E1a84EEB153331;
    bytes32 constant ACCOUNT_ID = 0x1794513e2fc05828d3205892dbef3c91eb7ffd6df62e0360acadd55650c9b672;
    bytes32 constant BROKER_HASH = 0xfb08c0b22085b07c3787ca55e02cc585a966b0799bfef3d32fc335d7107cedef;
    bytes32 constant TOKEN_HASH = 0x61fc29e9a6b4b52b423e75ca44734454f94ea60ddff3dc47af01a2a646fe9572;
    uint256 constant CHAIN_ID = 986532;
    uint64 constant WITHDRAW_NONCE = 123;
    AccountTypes.AccountDeposit depositData = AccountTypes.AccountDeposit({
        accountId: ACCOUNT_ID,
        brokerHash: BROKER_HASH,
        userAddress: SENDER,
        tokenHash: TOKEN_HASH,
        tokenAmount: AMOUNT,
        srcChainId: CHAIN_ID,
        srcChainDepositNonce: 1
    });

    // address(this) is 0x90193C961A926261B756D1E5bb255e67ff9498A1
    EventTypes.WithdrawData withdrawData = EventTypes.WithdrawData(
        ACCOUNT_ID,
        SENDER,
        SENDER,
        "woofi_dex",
        "USDC",
        AMOUNT,
        0,
        CHAIN_ID,
        WITHDRAW_NONCE,
        1686648201277,
        27,
        0x90b44cb1c50eaca38cdbb972180d5bd6a328825aa60dc8e25f1c2cb9f1abc4a8,
        0x5bb52b33ae0d9e1733c80da1163a33034ee433bf949e8c96beb940ece3ab5683
    );

    // address(this) is 0x78cA0A67bF6Cbe8Bf2429f0c7934eE5Dd687a32c
    EventTypes.WithdrawData withdrawData2 = EventTypes.WithdrawData(
        ACCOUNT_ID,
        SENDER,
        SENDER,
        "woofi_dex",
        "USDC",
        AMOUNT,
        0,
        CHAIN_ID,
        WITHDRAW_NONCE,
        1686723941381,
        28,
        0x53461c50a139b3124efcba37be7eb96ee842453bcb24a841475bbc3898b997ac,
        0x503c4cb84c2139d03f39be7cc49bef7764e5dcb8fd48ed64fc26a133c0e90462
    );

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

    function test_verify_EIP712() public {
        vm.chainId(CHAIN_ID);
        bool succ = VerifyEIP712.verifyWithdraw(withdrawData.sender, withdrawData);
        require(succ, "verify failed");
    }

    function testFail_verify_EIP712() public {
        vm.chainId(0xdead);
        bool succ = VerifyEIP712.verifyWithdraw(withdrawData.sender, withdrawData);
        require(succ, "verify failed");
    }

    function test_deposit() public {
        vm.prank(address(ledgerCrossChainManager));
        ledger.accountDeposit(depositData);
        assertEq(ledger.getUserLedgerBalance(ACCOUNT_ID, TOKEN_HASH), AMOUNT);
        assertEq(vaultManager.getBalance(CHAIN_ID, TOKEN_HASH), AMOUNT);
    }

    function test_withdraw() public {
        vm.prank(address(ledgerCrossChainManager));
        ledger.accountDeposit(depositData);
        vm.prank(address(operatorManager));
        vm.chainId(CHAIN_ID);
        ledger.executeWithdrawAction(withdrawData2, 1);
        assertEq(ledger.getUserLedgerBalance(ACCOUNT_ID, TOKEN_HASH), 0);
        assertEq(ledger.getFrozenTotalBalance(ACCOUNT_ID, TOKEN_HASH), AMOUNT);
        assertEq(ledger.getFrozenWithdrawNonce(ACCOUNT_ID, WITHDRAW_NONCE, TOKEN_HASH), AMOUNT);
    }
}

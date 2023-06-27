// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/OperatorManager.sol";
import "../src/Ledger.sol";
import "../src/VaultManager.sol";
import "./mock/LedgerCrossChainManagerMock.sol";
import "./mock/FeeManagerMock.sol";

contract LedgerTest is Test {
    address constant operatorAddress = address(0x1234567890);
    LedgerCrossChainManagerMock ledgerCrossChainManager;
    IOperatorManager operatorManager;
    IVaultManager vaultManager;
    ILedger ledger;
    IFeeManager feeManager;

    uint128 constant AMOUNT = 1000000;
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

    // address(this) is 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496
    EventTypes.WithdrawData withdrawData = EventTypes.WithdrawData(
        AMOUNT,
        0,
        CHAIN_ID,
        ACCOUNT_ID,
        0x6de54cc89be3597db5275c7d4dd135e20cd5e4bf9e15b91290652911c41079d6,
        0x2a9a28562e693658390672be9386e89f121a2f95d5c3fc395c77e2e8da2d867f,
        0x1b,
        SENDER,
        WITHDRAW_NONCE,
        SENDER,
        1687834683953,
        "woofi_dex",
        "USDC"
    );

    // address(this) is 0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9
    EventTypes.WithdrawData withdrawData2 = EventTypes.WithdrawData(
        AMOUNT,
        0,
        CHAIN_ID,
        ACCOUNT_ID,
        0xaf7765a771fb84359306155d44437e4cc2474dd6b3440730abec525e25894f9e,
        0x60cf03fc33c4f42c4313e722386a9e2a29e8e51e26f001e95c13d6780eefe403,
        0x1b,
        SENDER,
        WITHDRAW_NONCE,
        SENDER,
        1687835301453,
        "woofi_dex",
        "USDC"
    );

    AccountTypes.AccountWithdraw accountWithdraw = AccountTypes.AccountWithdraw({
        accountId: ACCOUNT_ID,
        sender: SENDER,
        receiver: SENDER,
        brokerHash: BROKER_HASH,
        tokenHash: TOKEN_HASH,
        tokenAmount: AMOUNT,
        fee: 0,
        chainId: CHAIN_ID,
        withdrawNonce: WITHDRAW_NONCE
    });

    function setUp() public {
        ledgerCrossChainManager = new LedgerCrossChainManagerMock();
        operatorManager = new OperatorManager();
        vaultManager = new VaultManager();
        ledger = new Ledger();
        feeManager = new FeeManagerMock();

        ledger.setOperatorManagerAddress(address(operatorManager));
        ledger.setCrossChainManager(address(ledgerCrossChainManager));
        ledger.setVaultManager(address(vaultManager));
        ledger.setFeeManager(address(feeManager));

        operatorManager.setOperator(operatorAddress);
        operatorManager.setLedger(address(ledger));

        ledgerCrossChainManager.setLedger(address(ledger));
        ledgerCrossChainManager.setOperatorManager(address(operatorManager));

        vaultManager.setLedgerAddress(address(ledger));

        feeManager.setLedgerAddress(address(ledger));
    }

    function test_verify_EIP712() public {
        vm.chainId(CHAIN_ID);
        bool succ = Signature.verifyWithdraw(withdrawData.sender, withdrawData);
        require(succ, "verify failed");
    }

    function testFail_verify_EIP712() public {
        vm.chainId(0xdead);
        bool succ = Signature.verifyWithdraw(withdrawData.sender, withdrawData);
        require(succ, "verify failed");
    }

    function test_deposit() public {
        vm.prank(address(ledgerCrossChainManager));
        ledger.accountDeposit(depositData);
        assertEq(ledger.getUserLedgerBalance(ACCOUNT_ID, TOKEN_HASH), AMOUNT);
        assertEq(vaultManager.getBalance(CHAIN_ID, TOKEN_HASH), AMOUNT);
    }

    function test_withdraw_approve() public {
        vm.prank(address(ledgerCrossChainManager));
        ledger.accountDeposit(depositData);
        vm.prank(address(operatorManager));
        vm.chainId(CHAIN_ID);
        ledger.executeWithdrawAction(withdrawData2, 1);
        assertEq(ledger.getUserLedgerBalance(ACCOUNT_ID, TOKEN_HASH), 0);
        assertEq(ledger.getFrozenTotalBalance(ACCOUNT_ID, TOKEN_HASH), AMOUNT);
        assertEq(ledger.getFrozenWithdrawNonce(ACCOUNT_ID, WITHDRAW_NONCE, TOKEN_HASH), AMOUNT);
    }

    function test_withdraw_finish() public {
        vm.prank(address(ledgerCrossChainManager));
        ledger.accountDeposit(depositData);
        vm.prank(address(operatorManager));
        vm.chainId(CHAIN_ID);
        ledger.executeWithdrawAction(withdrawData2, 1);
        assertEq(ledger.getUserLedgerBalance(ACCOUNT_ID, TOKEN_HASH), 0);
        assertEq(ledger.getFrozenTotalBalance(ACCOUNT_ID, TOKEN_HASH), AMOUNT);
        assertEq(ledger.getFrozenWithdrawNonce(ACCOUNT_ID, WITHDRAW_NONCE, TOKEN_HASH), AMOUNT);
        ledgerCrossChainManager.withdrawFinishMock(accountWithdraw);
        assertEq(ledger.getUserLedgerBalance(ACCOUNT_ID, TOKEN_HASH), 0);
        assertEq(ledger.getFrozenTotalBalance(ACCOUNT_ID, TOKEN_HASH), 0);
        assertEq(ledger.getFrozenWithdrawNonce(ACCOUNT_ID, WITHDRAW_NONCE, TOKEN_HASH), 0);
    }
}

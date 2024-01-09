// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../src/OperatorManager.sol";
import "../src/VaultManager.sol";
import "../src/MarketManager.sol";
import "../src/FeeManager.sol";
import "./mock/LedgerCrossChainManagerMock.sol";
import "./cheater/LedgerCheater.sol";
import "../src/LedgerImplA.sol";

contract LedgerTest is Test {
    ProxyAdmin admin;
    address constant operatorAddress = address(0x1234567890);
    LedgerCrossChainManagerMock ledgerCrossChainManager;
    IOperatorManager operatorManager;
    IVaultManager vaultManager;
    LedgerCheater ledger;
    IFeeManager feeManager;
    IMarketManager marketManager;
    TransparentUpgradeableProxy operatorProxy;
    TransparentUpgradeableProxy vaultProxy;
    TransparentUpgradeableProxy ledgerProxy;
    TransparentUpgradeableProxy feeProxy;
    TransparentUpgradeableProxy marketProxy;

    uint128 constant AMOUNT = 1000000;
    address constant SENDER = 0xc7ef8C0853CCB92232Aa158b2AF3e364f1BaE9a1;
    bytes32 constant ACCOUNT_ID = 0x6b97733ca568eddf2559232fa831f8de390a76d4f29a2962c3a9d0020383f7e3;
    bytes32 constant BROKER_HASH = 0x083098c593f395bea1de45dda552d9f14e8fcb0be3faaa7a1903c5477d7ba7fd;
    bytes32 constant TOKEN_HASH = 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa;
    uint256 constant CHAIN_ID = 986532;
    uint64 constant WITHDRAW_NONCE = 233;
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
        0x545c50021214976d1ef2ca5be753718b1b951050dc619c9ebb0a500465df0ac5,
        0x79f323773c4b34008e50e8b067a78669b341a3d5ebab1658847c9e03ff545cf3,
        0x1b,
        SENDER,
        WITHDRAW_NONCE,
        SENDER,
        1688110729953,
        "woofi_dex",
        "USDC"
    );

    // address(this) is 0xD6BbDE9174b1CdAa358d2Cf4D57D1a9F7178FBfF
    EventTypes.WithdrawData withdrawData2 = EventTypes.WithdrawData(
        AMOUNT,
        0,
        CHAIN_ID,
        ACCOUNT_ID,
        0xd07bc78e77ab1dac61bcfce876189e6d0458920658f3cf20fdde16b8d55a6d03,
        0x24fe74240344f3c40b9674f68a11c117f7be62bc307a0d449d3da6484e9ae18e,
        0x1b,
        SENDER,
        WITHDRAW_NONCE,
        SENDER,
        1688558006579,
        "woofi_dex",
        "USDC"
    );

    // // address(this) is 0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9
    // EventTypes.WithdrawData withdrawData2 = EventTypes.WithdrawData(
    //     AMOUNT,
    //     0,
    //     CHAIN_ID,
    //     ACCOUNT_ID,
    //     0xb107b0cb221d45555aa61fe9ea8ee372e4e310d6381f08cb99f06883836641ac,
    //     0x0927097d7625e8b73f2d87c3a60a06204667305f0369c1aa79f4f71e1dc99bbf,
    //     0x1b,
    //     SENDER,
    //     WITHDRAW_NONCE,
    //     SENDER,
    //     1688111795719,
    //     "woofi_dex",
    //     "USDC"
    // );

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
        admin = new ProxyAdmin();

        ledgerCrossChainManager = new LedgerCrossChainManagerMock();

        IOperatorManager operatorManagerImpl = new OperatorManager();
        IVaultManager vaultManagerImpl = new VaultManager();
        ILedger ledgerImpl = new LedgerCheater();
        IFeeManager feeImpl = new FeeManager();
        IMarketManager marketImpl = new MarketManager();

        bytes memory initData = abi.encodeWithSignature("initialize()");
        operatorProxy = new TransparentUpgradeableProxy(address(operatorManagerImpl), address(admin), initData);
        vaultProxy = new TransparentUpgradeableProxy(address(vaultManagerImpl), address(admin), initData);
        ledgerProxy = new TransparentUpgradeableProxy(address(ledgerImpl), address(admin), initData);
        feeProxy = new TransparentUpgradeableProxy(address(feeImpl), address(admin), initData);
        marketProxy = new TransparentUpgradeableProxy(address(marketImpl), address(admin), initData);

        operatorManager = IOperatorManager(address(operatorProxy));
        vaultManager = IVaultManager(address(vaultProxy));
        ledger = LedgerCheater(address(ledgerProxy));
        feeManager = IFeeManager(address(feeProxy));
        marketManager = IMarketManager(address(marketProxy));

        // do not change the order
        LedgerImplA ledgerImplA = new LedgerImplA();

        ledger.setOperatorManagerAddress(address(operatorManager));
        ledger.setCrossChainManager(address(ledgerCrossChainManager));
        ledger.setVaultManager(address(vaultManager));
        ledger.setFeeManager(address(feeManager));
        ledger.setMarketManager(address(marketManager));
        ledger.setLedgerImplA(address(ledgerImplA));

        operatorManager.setOperator(operatorAddress);
        operatorManager.setLedger(address(ledger));

        vaultManager.setLedgerAddress(address(ledger));
        if (!vaultManager.getAllowedToken(TOKEN_HASH)) {
            vaultManager.setAllowedToken(TOKEN_HASH, true);
        }
        if (!vaultManager.getAllowedBroker(BROKER_HASH)) {
            vaultManager.setAllowedBroker(BROKER_HASH, true);
        }
        vaultManager.setAllowedChainToken(TOKEN_HASH, CHAIN_ID, true);

        feeManager.setLedgerAddress(address(ledger));

        marketManager.setOperatorManagerAddress(address(operatorManager));
        marketManager.setLedgerAddress(address(ledger));

        ledgerCrossChainManager.setLedger(address(ledger));
        ledgerCrossChainManager.setOperatorManager(address(operatorManager));
    }

    function test_verify_EIP712() public {
        vm.chainId(CHAIN_ID);
        bool succ = Signature.verifyWithdraw(withdrawData.sender, withdrawData);
        require(succ, "verify failed");
    }

    function testRevert_verify_EIP712() public {
        withdrawData.chainId = 0xdead;
        bool succ = Signature.verifyWithdraw(withdrawData.sender, withdrawData);
        vm.expectRevert("verify failed");
        require(succ, "verify failed");
    }

    function test_deposit() public {
        vm.prank(address(ledgerCrossChainManager));
        ledger.accountDeposit(depositData);
        assertEq(ledger.getUserLedgerBalance(ACCOUNT_ID, TOKEN_HASH), AMOUNT);
        assertEq(vaultManager.getBalance(TOKEN_HASH, CHAIN_ID), AMOUNT);
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

    function testRevert_depositNotAllowedBroker() public {
        vaultManager.setAllowedBroker(BROKER_HASH, false);
        vm.prank(address(ledgerCrossChainManager));
        vm.expectRevert(IError.BrokerNotAllowed.selector);
        ledger.accountDeposit(depositData);
    }

    function testRevert_depositNotallowedChainToken() public {
        vaultManager.setAllowedChainToken(TOKEN_HASH, CHAIN_ID, false);
        vm.prank(address(ledgerCrossChainManager));
        vm.expectRevert(abi.encodeWithSelector(IError.TokenNotAllowed.selector, TOKEN_HASH, CHAIN_ID));
        ledger.accountDeposit(depositData);
    }

    function testRevert_depositInvalidAccountId() public {
        vm.prank(address(ledgerCrossChainManager));
        vm.expectRevert(IError.AccountIdInvalid.selector);
        depositData.accountId = 0x44a4d91d025846561e99ca284b96d282bc1f183c12c36471c58dee3747487d99;
        ledger.accountDeposit(depositData);
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

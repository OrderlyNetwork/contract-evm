// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../src/vaultSide/Vault.sol";
import "../src/vaultSide/tUSDC.sol";
import "./mock/VaultCrossChainManagerMock.sol";
import "./mock/LedgerCrossChainManagerMock.sol";

import "../src/OperatorManager.sol";
import "../src/VaultManager.sol";
import "../src/MarketManager.sol";
import "../src/FeeManager.sol";
import "./cheater/LedgerCheater.sol";
import "../src/LedgerImplA.sol";

import "forge-std/console.sol";

contract VaultTest is Test {
    ProxyAdmin admin;
    VaultCrossChainManagerMock vaultCrossChainManager;
    LedgerCrossChainManagerMock ledgerCrossChainManager;
    TestUSDC tUSDC;
    IVault vault;

    address constant operatorAddress = address(0x1234567890);
    IOperatorManager operatorManager;
    IVaultManager vaultManager;
    LedgerCheater ledger;
    IFeeManager feeManager;
    IMarketManager marketManager;
    TransparentUpgradeableProxy operatorProxy;
    TransparentUpgradeableProxy vaultProxyImp;
    TransparentUpgradeableProxy vaultProxyManager;
    TransparentUpgradeableProxy ledgerProxy;
    TransparentUpgradeableProxy feeProxy;
    TransparentUpgradeableProxy marketProxy;

    uint256 constant CHAIN_ID = 986532;
    uint128 constant AMOUNT = 1000000;
    uint128 constant AMOUNT2 = 500000;
    address constant SENDER_WITHDRAW = 0xc7ef8C0853CCB92232Aa158b2AF3e364f1BaE9a1;
    bytes32 constant ACCOUNT_ID_WITHDRAW = 0x6b97733ca568eddf2559232fa831f8de390a76d4f29a2962c3a9d0020383f7e3;
    address constant SENDER = 0x4FDDB51ADe1fa66952de254bE7E1a84EEB153331;
    bytes32 constant ACCOUNT_ID = 0x89bf2019fe60f13ec6c3f8de8c10156c2691ba5e743260dbcd81c2c66e87cba0;
    bytes32 constant BROKER_HASH = 0x083098c593f395bea1de45dda552d9f14e8fcb0be3faaa7a1903c5477d7ba7fd; // woofi_dex
    bytes32 constant TOKEN_HASH = 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa; // USDC
    uint64 constant WITHDRAW_NONCE = 233;

    VaultTypes.VaultDepositFE depositData = VaultTypes.VaultDepositFE({
        accountId: ACCOUNT_ID,
        brokerHash: BROKER_HASH,
        tokenHash: TOKEN_HASH,
        tokenAmount: AMOUNT
    });
    AccountTypes.AccountDeposit accountDepositData = AccountTypes.AccountDeposit({
        accountId: ACCOUNT_ID_WITHDRAW,
        brokerHash: BROKER_HASH,
        userAddress: SENDER_WITHDRAW,
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
        ACCOUNT_ID_WITHDRAW,
        0x545c50021214976d1ef2ca5be753718b1b951050dc619c9ebb0a500465df0ac5,
        0x79f323773c4b34008e50e8b067a78669b341a3d5ebab1658847c9e03ff545cf3,
        0x1b,
        SENDER_WITHDRAW,
        WITHDRAW_NONCE,
        SENDER_WITHDRAW,
        1688110729953,
        "woofi_dex",
        "USDC"
    );

    // address(this) is 0xD6BbDE9174b1CdAa358d2Cf4D57D1a9F7178FBfF
    EventTypes.WithdrawData withdrawData2 = EventTypes.WithdrawData(
        AMOUNT,
        0,
        CHAIN_ID,
        ACCOUNT_ID_WITHDRAW,
        0xd07bc78e77ab1dac61bcfce876189e6d0458920658f3cf20fdde16b8d55a6d03,
        0x24fe74240344f3c40b9674f68a11c117f7be62bc307a0d449d3da6484e9ae18e,
        0x1b,
        SENDER_WITHDRAW,
        WITHDRAW_NONCE,
        SENDER_WITHDRAW,
        1688558006579,
        "woofi_dex",
        "USDC"
    );

    AccountTypes.AccountWithdraw accountWithdraw = AccountTypes.AccountWithdraw({
        accountId: ACCOUNT_ID_WITHDRAW,
        sender: SENDER_WITHDRAW,
        receiver: SENDER_WITHDRAW,
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

        // setup ledger
        IOperatorManager operatorManagerImpl = new OperatorManager();
        IVaultManager vaultManagerImpl = new VaultManager();
        ILedger ledgerImpl = new LedgerCheater();
        IFeeManager feeImpl = new FeeManager();
        IMarketManager marketImpl = new MarketManager();

        bytes memory initData = abi.encodeWithSignature("initialize()");
        operatorProxy = new TransparentUpgradeableProxy(address(operatorManagerImpl), address(admin), initData);
        vaultProxyManager = new TransparentUpgradeableProxy(address(vaultManagerImpl), address(admin), initData);
        ledgerProxy = new TransparentUpgradeableProxy(address(ledgerImpl), address(admin), initData);
        feeProxy = new TransparentUpgradeableProxy(address(feeImpl), address(admin), initData);
        marketProxy = new TransparentUpgradeableProxy(address(marketImpl), address(admin), initData);

        operatorManager = IOperatorManager(address(operatorProxy));
        vaultManager = IVaultManager(address(vaultProxyManager));
        ledger = LedgerCheater(address(ledgerProxy));
        feeManager = IFeeManager(address(feeProxy));
        marketManager = IMarketManager(address(marketProxy));

        tUSDC = new TestUSDC();
        IVault vaultImpl = new Vault();
        vaultProxyImp = new TransparentUpgradeableProxy(address(vaultImpl), address(admin), "");
        vault = IVault(address(vaultProxyImp));
        vault.initialize();

        vault.changeTokenAddressAndAllow(TOKEN_HASH, address(tUSDC));
        vault.setAllowedBroker(BROKER_HASH, true);
        vaultCrossChainManager = new VaultCrossChainManagerMock();
        vault.setCrossChainManager(address(vaultCrossChainManager));

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

        // set VaultCCManagerMock -> LedgerCCManagerMock -> Ledger
        vaultCrossChainManager.setLedgerCCManagerMock(address(ledgerCrossChainManager));
        ledgerCrossChainManager.setLedger(address(ledger));
        // set LedgerCCManagerMock -> VaultCCManagerMock
        ledgerCrossChainManager.setVaultCCManagerMock(address(vaultCrossChainManager));
        vaultCrossChainManager.setVault(address(vault));
    }

    function test_Crossdeposit() public {
        vm.startPrank(SENDER);
        tUSDC.mint(SENDER, AMOUNT);
        tUSDC.approve(address(vault), AMOUNT);
        assertEq(tUSDC.balanceOf(address(SENDER)), AMOUNT);

        vault.deposit(depositData);
        vm.stopPrank();
        assertEq(tUSDC.balanceOf(address(SENDER)), 0);
        assertEq(tUSDC.balanceOf(address(vault)), AMOUNT);
        assertTrue(vaultCrossChainManager.calledDeposit());

        vm.prank(address(ledgerCrossChainManager));
        assertEq(ledger.getUserLedgerBalance(ACCOUNT_ID, TOKEN_HASH), AMOUNT);
        assertEq(vaultManager.getBalance(TOKEN_HASH, CHAIN_ID), AMOUNT);
    }

    function test_Crosswithdraw() public {
        // User && Vault balance check
        assertEq(tUSDC.balanceOf(address(SENDER_WITHDRAW)), 0);
        assertEq(tUSDC.balanceOf(address(vault)), 0);

        // Assuming cross-chain arrival
        tUSDC.mint(address(vault), AMOUNT);
        assertEq(tUSDC.balanceOf(address(vault)), AMOUNT);

        vm.prank(address(ledgerCrossChainManager));
        ledger.accountDeposit(accountDepositData);
        vm.prank(address(operatorManager));
        vm.chainId(CHAIN_ID);

        ledger.executeWithdrawAction(withdrawData2, 1);
        assertEq(ledger.getUserLedgerBalance(ACCOUNT_ID_WITHDRAW, TOKEN_HASH), 0);
        assertEq(ledger.getFrozenTotalBalance(ACCOUNT_ID_WITHDRAW, TOKEN_HASH), AMOUNT);
        assertEq(ledger.getFrozenWithdrawNonce(ACCOUNT_ID_WITHDRAW, WITHDRAW_NONCE, TOKEN_HASH), AMOUNT);

        ledgerCrossChainManager.withdrawFinishMock(accountWithdraw);
        assertEq(ledger.getUserLedgerBalance(ACCOUNT_ID_WITHDRAW, TOKEN_HASH), 0);
        assertEq(ledger.getFrozenTotalBalance(ACCOUNT_ID_WITHDRAW, TOKEN_HASH), 0);
        assertEq(ledger.getFrozenWithdrawNonce(ACCOUNT_ID_WITHDRAW, WITHDRAW_NONCE, TOKEN_HASH), 0);
        assertTrue(ledgerCrossChainManager.calledwithdraw());

        // User && Vault balance check
        assertEq(tUSDC.balanceOf(address(SENDER_WITHDRAW)), AMOUNT);
        assertEq(tUSDC.balanceOf(address(vault)), 0);
    }
}

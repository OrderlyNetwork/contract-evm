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
    TransparentUpgradeableProxy vaultProxy;
    uint128 constant AMOUNT = 1000000;
    address constant SENDER = 0x4FDDB51ADe1fa66952de254bE7E1a84EEB153331;
    bytes32 constant ACCOUNT_ID = 0x89bf2019fe60f13ec6c3f8de8c10156c2691ba5e743260dbcd81c2c66e87cba0;
    bytes32 constant BROKER_HASH = 0x083098c593f395bea1de45dda552d9f14e8fcb0be3faaa7a1903c5477d7ba7fd; // woofi_dex
    bytes32 constant TOKEN_HASH = 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa; // USDC
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

    uint256 constant CHAIN_ID = 986532;
    address constant operatorAddress = address(0x1234567890);
    IOperatorManager operatorManager;
    IVaultManager vaultManager;
    LedgerCheater ledger;
    IFeeManager feeManager;
    IMarketManager marketManager;
    TransparentUpgradeableProxy operatorProxy;
    // TransparentUpgradeableProxy vaultProxy;
    TransparentUpgradeableProxy ledgerProxy;
    TransparentUpgradeableProxy feeProxy;
    TransparentUpgradeableProxy marketProxy;

    function setUp() public {
        admin = new ProxyAdmin();

        tUSDC = new TestUSDC();
        IVault vaultImpl = new Vault();
        vaultProxy = new TransparentUpgradeableProxy(address(vaultImpl), address(admin), "");
        vault = IVault(address(vaultProxy));
        vault.initialize();

        vault.changeTokenAddressAndAllow(TOKEN_HASH, address(tUSDC));
        vault.setAllowedBroker(BROKER_HASH, true);
        vaultCrossChainManager = new VaultCrossChainManagerMock();
        vault.setCrossChainManager(address(vaultCrossChainManager));
        ledgerCrossChainManager = new LedgerCrossChainManagerMock();

        // setup ledger
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

        // set VaultCCManagerMock -> LedgerCCManagerMock -> Ledger
        vaultCrossChainManager.setLedgerCCManagerMock(address(ledgerCrossChainManager));
        ledgerCrossChainManager.setLedger(address(ledger));
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
        assertTrue(vaultCrossChainManager.calledDeposit());
    }

    function testRevert_depositInsufficientAmount() public {
        vm.startPrank(SENDER);
        tUSDC.mint(SENDER, AMOUNT - 1);
        tUSDC.approve(address(vault), AMOUNT);
        assertEq(tUSDC.balanceOf(address(SENDER)), AMOUNT - 1);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        vault.deposit(depositData);
    }

    function testRevert_depositInsufficientApproval() public {
        vm.startPrank(SENDER);
        tUSDC.mint(SENDER, AMOUNT);
        tUSDC.approve(address(vault), AMOUNT - 1);
        assertEq(tUSDC.balanceOf(address(SENDER)), AMOUNT);

        vm.expectRevert("ERC20: insufficient allowance");
        vault.deposit(depositData);
    }

    function testRevert_depositNotAllowedToken() public {
        vm.startPrank(SENDER);
        depositData.tokenHash = 0x96706879d29c248edfb2a2563a8a9d571c49634c0f82013e6f5a7cde739d35d4; // "TOKEN"

        vm.expectRevert(IVault.TokenNotAllowed.selector);
        vault.deposit(depositData);
        vm.stopPrank();
    }

    function testRevert_depositNotAllowedBroker() public {
        vm.startPrank(SENDER);
        depositData.brokerHash = 0x2804e22f743595918807e939e50f80985ef77d3aa68cd82cff712cc69eee98ec; // "brokerId"
        vm.expectRevert(IVault.BrokerNotAllowed.selector);
        vault.deposit(depositData);
        vm.stopPrank();
    }

    function testRevert_depositIncorrectAccountId() public {
        vm.startPrank(SENDER);
        tUSDC.mint(SENDER, AMOUNT);
        tUSDC.approve(address(vault), AMOUNT);
        assertEq(tUSDC.balanceOf(address(SENDER)), AMOUNT);
        depositData.accountId = 0x44a4d91d025846561e99ca284b96d282bc1f183c12c36471c58dee3747487d99; // keccak(SENDER, keccak("brokerId"))
        vm.expectRevert(IVault.AccountIdInvalid.selector);
        vault.deposit(depositData);
        vm.stopPrank();
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

    function testRevert_withdrawInsufficientBalance() public {
        vm.startPrank(SENDER);
        tUSDC.mint(SENDER, AMOUNT);
        tUSDC.approve(address(vault), AMOUNT);
        depositData.tokenAmount = AMOUNT - 1;
        vault.deposit(depositData);
        vm.stopPrank();

        vm.prank(address(vaultCrossChainManager));
        vm.expectRevert();
        vault.withdraw(withdrawData);
    }

    function test_getAllWhitelistSet() public {
        vault.changeTokenAddressAndAllow(TOKEN_HASH, address(tUSDC));
        if (!vault.getAllowedBroker(BROKER_HASH)) {
            vault.setAllowedBroker(BROKER_HASH, true);
        }
        assertEq(vault.getAllAllowedBroker().length, 1);
        assertEq(vault.getAllAllowedToken().length, 1);
    }

    function test_whitelist() public {
        vault.changeTokenAddressAndAllow(TOKEN_HASH, address(tUSDC));
        if (!vault.getAllowedBroker(BROKER_HASH)) {
            vault.setAllowedBroker(BROKER_HASH, true);
        }
        assertEq(vault.getAllowedToken(TOKEN_HASH), address(tUSDC));
        assertEq(vault.getAllowedBroker(BROKER_HASH), true);

        vault.setAllowedToken(TOKEN_HASH, false);
        if (vault.getAllowedBroker(BROKER_HASH)) {
            vault.setAllowedBroker(BROKER_HASH, false);
        }
        assertEq(vault.getAllowedToken(TOKEN_HASH), address(0));
        assertEq(vault.getAllowedBroker(BROKER_HASH), false);

        vault.setAllowedToken(TOKEN_HASH, true);
        if (!vault.getAllowedBroker(BROKER_HASH)) {
            vault.setAllowedBroker(BROKER_HASH, true);
        }
        assertEq(vault.getAllowedToken(TOKEN_HASH), address(tUSDC));
        assertEq(vault.getAllowedBroker(BROKER_HASH), true);
    }

    function test_depositExceedLimit_0() public {
        vault.setDepositLimit(address(tUSDC), AMOUNT);

        vm.startPrank(SENDER);
        tUSDC.mint(SENDER, AMOUNT);
        tUSDC.approve(address(vault), AMOUNT);
        vault.deposit(depositData);
        vm.stopPrank();

        vault.setDepositLimit(address(tUSDC), AMOUNT * 2);

        vm.startPrank(SENDER);
        tUSDC.mint(SENDER, AMOUNT);
        tUSDC.approve(address(vault), AMOUNT);
        vault.deposit(depositData);
        vm.stopPrank();
    }

    function testRevert_depositExceedLimit_1() public {
        vault.setDepositLimit(address(tUSDC), AMOUNT - 1);

        vm.startPrank(SENDER);
        tUSDC.mint(SENDER, AMOUNT);
        tUSDC.approve(address(vault), AMOUNT);
        vm.expectRevert(IVault.DepositExceedLimit.selector);
        vault.deposit(depositData);
        vm.stopPrank();
    }

    function testRevert_depositExceedLimit_2() public {
        vault.setDepositLimit(address(tUSDC), AMOUNT + 1);

        vm.startPrank(SENDER);
        tUSDC.mint(SENDER, AMOUNT);
        tUSDC.approve(address(vault), AMOUNT);
        vault.deposit(depositData);
        vm.stopPrank();

        vm.startPrank(SENDER);
        tUSDC.mint(SENDER, AMOUNT);
        tUSDC.approve(address(vault), AMOUNT);
        vm.expectRevert(IVault.DepositExceedLimit.selector);
        vault.deposit(depositData);
        vm.stopPrank();
    }
}

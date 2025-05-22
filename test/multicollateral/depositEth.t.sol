// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/vaultSide/Vault.sol";
import "../mock/VaultCrossChainManagerMock.sol";
import "../mock/LedgerCrossChainManagerMock.sol";

import "../../src/OperatorManager.sol";
import "../../src/VaultManager.sol";
import "../../src/MarketManager.sol";
import "../../src/FeeManager.sol";
import "../cheater/LedgerCheater.sol";
import "../../src/LedgerImplA.sol";

import "forge-std/console.sol";

contract DepositEthTest is Test {
    ProxyAdmin admin;
    VaultCrossChainManagerMock vaultCrossChainManager;
    LedgerCrossChainManagerMock ledgerCrossChainManager;
    Vault vault;
    TransparentUpgradeableProxy vaultProxy;
    
    uint128 constant AMOUNT = 1 ether;
    address constant SENDER = 0x4FDDB51ADe1fa66952de254bE7E1a84EEB153331;
    bytes32 constant ACCOUNT_ID = 0x89bf2019fe60f13ec6c3f8de8c10156c2691ba5e743260dbcd81c2c66e87cba0;
    bytes32 constant BROKER_HASH = 0x083098c593f395bea1de45dda552d9f14e8fcb0be3faaa7a1903c5477d7ba7fd; // woofi_dex
    bytes32 constant ETH_HASH = 0x8ae85d849167ff996c04040c44924fd364217285e4cad818292c7ac37c0a345b; // ETH

    // Deposit data structure for native token ETH
    VaultTypes.VaultDepositFE depositData = VaultTypes.VaultDepositFE({
        accountId: ACCOUNT_ID,
        brokerHash: BROKER_HASH,
        tokenHash: ETH_HASH,
        tokenAmount: AMOUNT
    });

    uint256 constant CHAIN_ID = 986532;
    address constant operatorAddress = address(0x1234567890);
    IOperatorManager operatorManager;
    IVaultManager vaultManager;
    LedgerCheater ledger;
    IFeeManager feeManager;
    IMarketManager marketManager;
    TransparentUpgradeableProxy operatorProxy;
    TransparentUpgradeableProxy ledgerProxy;
    TransparentUpgradeableProxy feeProxy;
    TransparentUpgradeableProxy marketProxy;
    TransparentUpgradeableProxy vaultManagerProxy;

    function setUp() public {
        admin = new ProxyAdmin();

        // Setup Vault
        IVault vaultImpl = new Vault();
        vaultProxy = new TransparentUpgradeableProxy(address(vaultImpl), address(admin), "");
        vault = Vault(address(vaultProxy));
        vault.initialize();

        // Setup native token ETH hash and broker
        vault.setNativeTokenHash(ETH_HASH);
        vault.setAllowedToken(ETH_HASH, true);
        vault.setAllowedBroker(BROKER_HASH, true);
        
        // Setup cross-chain managers
        vaultCrossChainManager = new VaultCrossChainManagerMock();
        vault.setCrossChainManager(address(vaultCrossChainManager));
        ledgerCrossChainManager = new LedgerCrossChainManagerMock();

        // Setup ledger components
        IOperatorManager operatorManagerImpl = new OperatorManager();
        IVaultManager vaultManagerImpl = new VaultManager();
        ILedger ledgerImpl = new LedgerCheater();
        IFeeManager feeImpl = new FeeManager();
        IMarketManager marketImpl = new MarketManager();

        bytes memory initData = abi.encodeWithSignature("initialize()");
        operatorProxy = new TransparentUpgradeableProxy(address(operatorManagerImpl), address(admin), initData);
        vaultManagerProxy = new TransparentUpgradeableProxy(address(vaultManagerImpl), address(admin), initData);
        ledgerProxy = new TransparentUpgradeableProxy(address(ledgerImpl), address(admin), initData);
        feeProxy = new TransparentUpgradeableProxy(address(feeImpl), address(admin), initData);
        marketProxy = new TransparentUpgradeableProxy(address(marketImpl), address(admin), initData);

        operatorManager = IOperatorManager(address(operatorProxy));
        vaultManager = IVaultManager(address(vaultManagerProxy));
        ledger = LedgerCheater(address(ledgerProxy));
        feeManager = IFeeManager(address(feeProxy));
        marketManager = IMarketManager(address(marketProxy));

        // Initialize ledger implementation
        LedgerImplA ledgerImplA = new LedgerImplA();

        // Connect all components
        ledger.setOperatorManagerAddress(address(operatorManager));
        ledger.setCrossChainManager(address(ledgerCrossChainManager));
        ledger.setVaultManager(address(vaultManager));
        ledger.setFeeManager(address(feeManager));
        ledger.setMarketManager(address(marketManager));
        ledger.setLedgerImplA(address(ledgerImplA));

        operatorManager.setOperator(operatorAddress);
        operatorManager.setLedger(address(ledger));

        vaultManager.setLedgerAddress(address(ledger));
        if (!vaultManager.getAllowedToken(ETH_HASH)) {
            vaultManager.setAllowedToken(ETH_HASH, true);
        }
        if (!vaultManager.getAllowedBroker(BROKER_HASH)) {
            vaultManager.setAllowedBroker(BROKER_HASH, true);
        }
        vaultManager.setAllowedChainToken(ETH_HASH, CHAIN_ID, true);

        feeManager.setLedgerAddress(address(ledger));

        marketManager.setOperatorManagerAddress(address(operatorManager));
        marketManager.setLedgerAddress(address(ledger));

        // Set up cross-chain communication
        ledgerCrossChainManager.setLedger(address(ledger));
        ledgerCrossChainManager.setVaultCCManagerMock(address(vaultCrossChainManager));
        vaultCrossChainManager.setLedgerCCManagerMock(address(ledgerCrossChainManager));
        vaultCrossChainManager.setVault(address(vault));
        
        // Fund test address
        vm.deal(SENDER, 10 ether);
    }

    function test_ethDeposit() public {

        vm.startPrank(SENDER);
        
        // event AccountDeposit(
        //     bytes32 indexed accountId,
        //     uint64 indexed depositNonce,
        //     uint64 indexed eventId,
        //     address userAddress,
        //     bytes32 tokenHash,
        //     uint128 tokenAmount,
        //     uint256 srcChainId,
        //     uint64 srcChainDepositNonce,
        //     bytes32 brokerHash
        // );
        // Deposit ETH with exact amount
        // expect emit AccountDeposit event
        vm.expectEmit(true, true, true, true);
        emit ILedgerEvent.AccountDeposit(
            depositData.accountId,
            1,
            1,
            SENDER,
            depositData.tokenHash,
            AMOUNT,
            CHAIN_ID,
            1,
            depositData.brokerHash
        );
        vault.deposit{value: AMOUNT}(depositData);
        
        vm.stopPrank();
        
        // Check that vault received the ETH
        assertEq(address(vault).balance, AMOUNT);
        // Check that the deposit was processed by the cross-chain manager mock
        assertTrue(vaultCrossChainManager.calledDeposit());
    }
    
    function test_ethDepositTo() public {
        address receiver = address(0x5555);

        VaultTypes.VaultDepositFE memory toDepositData = depositData;
        toDepositData.accountId = keccak256(abi.encode(receiver, depositData.brokerHash));
        
        vm.startPrank(SENDER);
        
        vm.expectEmit(true, true, true, true);
        emit ILedgerEvent.AccountDeposit(
            toDepositData.accountId,
            1,
            1,
            receiver,
            toDepositData.tokenHash,
            toDepositData.tokenAmount,
            CHAIN_ID,
            1,
            toDepositData.brokerHash
        );
        // Deposit ETH on behalf of another user
        vault.depositTo{value: AMOUNT}(receiver, toDepositData);
        
        vm.stopPrank();
        
        // Check that vault received the ETH
        assertEq(address(vault).balance, AMOUNT);
        // Check that the deposit was processed by the cross-chain manager mock
        assertTrue(vaultCrossChainManager.calledDeposit());
    }
    
    function testRevert_ethDepositInsufficientAmount() public {
        vm.startPrank(SENDER);
        
        // Try to deposit with less ETH than specified in deposit data
        vm.expectRevert(IVault.NativeTokenDepositAmountMismatch.selector);
        vault.deposit{value: AMOUNT - 100}(depositData);
        
        vm.stopPrank();
    }
    
    function test_ethDepositWithFee() public {
        // Enable deposit fee
        vm.prank(address(vault.owner()));
        vault.enableDepositFee(true);
        
        uint256 depositAmount = AMOUNT;
        uint256 feeAmount = vault.getDepositFee(SENDER, depositData);
        uint256 totalAmount = depositAmount + feeAmount;
        
        vm.startPrank(SENDER);
        
        // Deposit ETH with fee
        vault.deposit{value: totalAmount}(depositData);
        
        vm.stopPrank();
        
        // Check that vault received the ETH
        assertEq(address(vault).balance, depositAmount);
        // Check that depositWithFeeRefund was called
        assertTrue(vaultCrossChainManager.calledDepositWithFeeRefund());
    }

    function testRevert_ethDepositWithFeeInsufficientAmount() public {
        // Enable deposit fee
        vm.prank(address(vault.owner()));
        vault.enableDepositFee(true);

        // uint256 feeAmount = vault.getDepositFee(SENDER, depositData);

        vm.startPrank(SENDER);
        
        // Try to deposit with 0 deposit fee
        vm.expectRevert(IVault.ZeroDepositFee.selector);
        vault.deposit{value: AMOUNT}(depositData);

        // Try to deposit with insufficient deposit fee
        // expect revert with "Amount must be greater than deposit fee."
        vm.expectRevert("Amount must be greater than deposit fee.");
        vault.deposit{value: AMOUNT + 0.001 ether}(depositData);
        
        vm.stopPrank();
    }
    
    function testRevert_ethDepositExceedLimit() public {
        // Set native token deposit limit
        vm.startPrank(address(vault.owner()));
        vault.setNativeTokenDepositLimit(AMOUNT - 1);
        vm.stopPrank();
        
        vm.startPrank(SENDER);
        
        // Try to deposit more than the limit
        vm.expectRevert(IVault.DepositExceedLimit.selector);
        vault.deposit{value: AMOUNT}(depositData);
        
        vm.stopPrank();
    }
    
    function testRevert_ethDepositFeeNotEnabled() public {
        // Make sure deposit fee is disabled
        vm.prank(address(vault.owner()));
        vault.enableDepositFee(false);
        
        vm.startPrank(SENDER);
        
        // Deposit with exact amount (no fee)
        vault.deposit{value: AMOUNT}(depositData);
        
        vm.stopPrank();
        
        // Should have called deposit (not depositWithFeeRefund)
        assertTrue(vaultCrossChainManager.calledDeposit());
        assertFalse(vaultCrossChainManager.calledDepositWithFeeRefund());
    }
    
    function testRevert_ethDepositNoFeeWhenRequired() public {
        // Enable deposit fee
        vm.prank(address(vault.owner()));
        vault.enableDepositFee(true);
        
        vm.startPrank(SENDER);
        
        // Try to deposit with exact amount (no fee) when fee is required
        vm.expectRevert(IVault.ZeroDepositFee.selector);
        vault.deposit{value: AMOUNT}(depositData);
        
        vm.stopPrank();
    }

    /// @notice Test that the deposit reverts when the token is not allowed
    function testRevert_ethDepositTokenNotAllowed() public {
        vm.prank(address(vault.owner()));
        vault.setAllowedToken(ETH_HASH, false);
        // Set token not allowed
        vm.startPrank(address(vault.owner()));
        vm.expectRevert(IVault.TokenNotAllowed.selector);
        vault.deposit{value: AMOUNT}(depositData);
        vm.expectRevert(IVault.TokenNotAllowed.selector);
        vault.depositTo{value: AMOUNT}(address(0x1234), depositData);
        vm.stopPrank();
    }
    
}

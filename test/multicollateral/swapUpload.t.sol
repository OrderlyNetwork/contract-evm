// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/OperatorManager.sol";
import "../../src/VaultManager.sol";
import "../../src/MarketManager.sol";
import "../../src/FeeManager.sol";
import "../mock/LedgerCrossChainManagerMock.sol";
import "../cheater/LedgerCheater.sol";
import "../../src/LedgerImplA.sol";
import "../../src/LedgerImplD.sol";

import "../../src/vaultSide/Vault.sol";
import "../../src/vaultSide/tUSDC.sol";
import "../../src/library/typesHelper/SafeCastHelper.sol";

contract SwapUploadTest is Test {
    using SafeCastHelper for uint128;

    ProxyAdmin admin;
    VaultCrossChainManagerMock vaultCrossChainManager;
    LedgerCrossChainManagerMock ledgerCrossChainManager;
    TestUSDC tUSDC;
    TestUSDC tWETH; // Mock WETH token
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

    uint128 constant INITIAL_USDC_AMOUNT = 1000000; // 1 USDC
    uint128 constant INITIAL_WETH_AMOUNT = 500000000000000000; // 0.5 WETH
    int128 constant SWAP_BUY_QUANTITY = 300000000000000000; // 0.3 WETH
    int128 constant SWAP_SELL_QUANTITY = -600000; // -0.6 USDC (negative for selling)
    
    address constant SENDER = 0xc7ef8C0853CCB92232Aa158b2AF3e364f1BaE9a1;
    bytes32 constant ACCOUNT_ID = 0x6b97733ca568eddf2559232fa831f8de390a76d4f29a2962c3a9d0020383f7e3;
    bytes32 constant BROKER_HASH = 0x083098c593f395bea1de45dda552d9f14e8fcb0be3faaa7a1903c5477d7ba7fd;
    bytes32 constant USDC_TOKEN_HASH = 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa;
    bytes32 constant WETH_TOKEN_HASH = 0xaaaebeba3810b1e6b70781f14b2d72c1cb89c0b2b320c43bb67ff79f562f5ff4;
    uint256 constant CHAIN_ID = 986532;

    // Deposit data for USDC
    AccountTypes.AccountDeposit usdcDepositData = AccountTypes.AccountDeposit({
        accountId: ACCOUNT_ID,
        brokerHash: BROKER_HASH,
        userAddress: SENDER,
        tokenHash: USDC_TOKEN_HASH,
        tokenAmount: INITIAL_USDC_AMOUNT,
        srcChainId: CHAIN_ID,
        srcChainDepositNonce: 1
    });

    // Deposit data for WETH
    AccountTypes.AccountDeposit wethDepositData = AccountTypes.AccountDeposit({
        accountId: ACCOUNT_ID,
        brokerHash: BROKER_HASH,
        userAddress: SENDER,
        tokenHash: WETH_TOKEN_HASH,
        tokenAmount: INITIAL_WETH_AMOUNT,
        srcChainId: CHAIN_ID,
        srcChainDepositNonce: 2
    });

    // Swap result data: sell USDC, buy WETH
    EventTypes.SwapResult swapResultData = EventTypes.SwapResult({
        accountId: ACCOUNT_ID,
        buyTokenHash: WETH_TOKEN_HASH,
        sellTokenHash: USDC_TOKEN_HASH,
        buyQuantity: SWAP_BUY_QUANTITY,
        sellQuantity: SWAP_SELL_QUANTITY,
        chainId: CHAIN_ID,
        swapStatus: 0
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
        vaultProxyManager = new TransparentUpgradeableProxy(address(vaultManagerImpl), address(admin), initData);
        ledgerProxy = new TransparentUpgradeableProxy(address(ledgerImpl), address(admin), initData);
        feeProxy = new TransparentUpgradeableProxy(address(feeImpl), address(admin), initData);
        marketProxy = new TransparentUpgradeableProxy(address(marketImpl), address(admin), initData);

        operatorManager = IOperatorManager(address(operatorProxy));
        vaultManager = IVaultManager(address(vaultProxyManager));
        ledger = LedgerCheater(address(ledgerProxy));
        feeManager = IFeeManager(address(feeProxy));
        marketManager = IMarketManager(address(marketProxy));

        // Create mock tokens
        tUSDC = new TestUSDC();
        tWETH = new TestUSDC(); // Using TestUSDC as mock WETH for simplicity
        
        IVault vaultImpl = new Vault();
        vaultProxyImp = new TransparentUpgradeableProxy(address(vaultImpl), address(admin), "");
        vault = IVault(address(vaultProxyImp));
        vault.initialize();

        // Setup vault with both tokens
        vault.changeTokenAddressAndAllow(USDC_TOKEN_HASH, address(tUSDC));
        vault.changeTokenAddressAndAllow(WETH_TOKEN_HASH, address(tWETH));
        vault.setAllowedBroker(BROKER_HASH, true);
        vaultCrossChainManager = new VaultCrossChainManagerMock();
        vault.setCrossChainManager(address(vaultCrossChainManager));

        // Setup ledger implementations
        LedgerImplA ledgerImplA = new LedgerImplA();
        LedgerImplD ledgerImplD = new LedgerImplD();

        ledger.setOperatorManagerAddress(address(operatorManager));
        ledger.setCrossChainManager(address(ledgerCrossChainManager));
        ledger.setVaultManager(address(vaultManager));
        ledger.setFeeManager(address(feeManager));
        ledger.setMarketManager(address(marketManager));
        ledger.setLedgerImplA(address(ledgerImplA));
        ledger.setLedgerImplD(address(ledgerImplD));

        operatorManager.setOperator(operatorAddress);
        operatorManager.setLedger(address(ledger));

        vaultManager.setLedgerAddress(address(ledger));
        
        // Allow both tokens
        if (!vaultManager.getAllowedToken(USDC_TOKEN_HASH)) {
            vaultManager.setAllowedToken(USDC_TOKEN_HASH, true);
        }
        if (!vaultManager.getAllowedToken(WETH_TOKEN_HASH)) {
            vaultManager.setAllowedToken(WETH_TOKEN_HASH, true);
        }
        
        if (!vaultManager.getAllowedBroker(BROKER_HASH)) {
            vaultManager.setAllowedBroker(BROKER_HASH, true);
        }
        
        vaultManager.setAllowedChainToken(USDC_TOKEN_HASH, CHAIN_ID, true);
        vaultManager.setAllowedChainToken(WETH_TOKEN_HASH, CHAIN_ID, true);

        feeManager.setLedgerAddress(address(ledger));

        marketManager.setOperatorManagerAddress(address(operatorManager));
        marketManager.setLedgerAddress(address(ledger));

        ledgerCrossChainManager.setLedger(address(ledger));
        ledgerCrossChainManager.setOperatorManager(address(operatorManager));

        // Set cross-chain manager connections
        vaultCrossChainManager.setLedgerCCManagerMock(address(ledgerCrossChainManager));
        ledgerCrossChainManager.setLedger(address(ledger));
        ledgerCrossChainManager.setVaultCCManagerMock(address(vaultCrossChainManager));
        vaultCrossChainManager.setVault(address(vault));

        // Mint tokens to vault
        tUSDC.mint(address(vault), INITIAL_USDC_AMOUNT * 10); // Mint extra for testing
        tWETH.mint(address(vault), INITIAL_WETH_AMOUNT * 10); // Mint extra for testing
    }

    function test_swapResultUpload_success() public {
        // First deposit both tokens to the account
        vm.prank(address(ledgerCrossChainManager));
        ledger.accountDeposit(usdcDepositData);
        
        vm.prank(address(ledgerCrossChainManager));
        ledger.accountDeposit(wethDepositData);

        // Verify initial balances
        assertEq(ledger.getUserLedgerBalance(ACCOUNT_ID, USDC_TOKEN_HASH), INITIAL_USDC_AMOUNT.toInt128());
        assertEq(ledger.getUserLedgerBalance(ACCOUNT_ID, WETH_TOKEN_HASH), INITIAL_WETH_AMOUNT.toInt128());

        // Execute swap result upload
        uint64 eventId = 123;
        vm.prank(address(operatorManager));
        ledger.executeSwapResultUpload(swapResultData, eventId);

        // Verify balances after swap
        int128 expectedUsdcBalance = INITIAL_USDC_AMOUNT.toInt128() + SWAP_SELL_QUANTITY;
        int128 expectedWethBalance = INITIAL_WETH_AMOUNT.toInt128() + SWAP_BUY_QUANTITY;
        
        assertEq(ledger.getUserLedgerBalance(ACCOUNT_ID, USDC_TOKEN_HASH), expectedUsdcBalance);
        assertEq(ledger.getUserLedgerBalance(ACCOUNT_ID, WETH_TOKEN_HASH), expectedWethBalance);
    }

    function test_swapResultUpload_emitsEvent() public {
        // Setup initial deposits
        vm.prank(address(ledgerCrossChainManager));
        // event id 1
        ledger.accountDeposit(usdcDepositData);
        // event id 2
        vm.prank(address(ledgerCrossChainManager));
        ledger.accountDeposit(wethDepositData);

        uint64 eventId = 456;
        
        // Expect the SwapResultUploaded event
        vm.expectEmit(true, true, false, true);
        emit SwapResultUploaded(
            3, // globalEventId should be 3 
            ACCOUNT_ID,
            WETH_TOKEN_HASH,
            USDC_TOKEN_HASH,
            SWAP_BUY_QUANTITY,
            SWAP_SELL_QUANTITY,
            CHAIN_ID,
            0
        );

        vm.prank(address(operatorManager));
        ledger.executeSwapResultUpload(swapResultData, eventId);
    }

    function test_swapResultUpload_multipleSwaps() public {
        // Setup initial deposits
        vm.prank(address(ledgerCrossChainManager));
        ledger.accountDeposit(usdcDepositData);
        
        vm.prank(address(ledgerCrossChainManager));
        ledger.accountDeposit(wethDepositData);

        // First swap: sell USDC, buy WETH
        vm.prank(address(operatorManager));
        ledger.executeSwapResultUpload(swapResultData, 1);

        // Second swap: sell WETH, buy USDC (reverse)
        EventTypes.SwapResult memory reverseSwapData = EventTypes.SwapResult({
            accountId: ACCOUNT_ID,
            buyTokenHash: USDC_TOKEN_HASH,
            sellTokenHash: WETH_TOKEN_HASH,
            buyQuantity: -SWAP_SELL_QUANTITY / 2, // Buy half the USDC back (positive quantity)
            sellQuantity: -SWAP_BUY_QUANTITY / 2,  // Sell half the WETH (negative quantity)
            chainId: CHAIN_ID,
            swapStatus: 0
        });

        vm.prank(address(operatorManager));
        ledger.executeSwapResultUpload(reverseSwapData, 2);

        // Calculate expected final balances
        int128 finalUsdcBalance = INITIAL_USDC_AMOUNT.toInt128() 
            + SWAP_SELL_QUANTITY 
            + (-SWAP_SELL_QUANTITY / 2);
            
        int128 finalWethBalance = INITIAL_WETH_AMOUNT.toInt128() 
            + SWAP_BUY_QUANTITY 
            + (-SWAP_BUY_QUANTITY / 2);

        assertEq(ledger.getUserLedgerBalance(ACCOUNT_ID, USDC_TOKEN_HASH), finalUsdcBalance);
        assertEq(ledger.getUserLedgerBalance(ACCOUNT_ID, WETH_TOKEN_HASH), finalWethBalance);
    }

    function testRevert_swapResultUpload_onlyOperator() public {
        // Setup initial deposits
        vm.prank(address(ledgerCrossChainManager));
        ledger.accountDeposit(usdcDepositData);

        // Try to call from non-operator address
        vm.prank(SENDER);
        vm.expectRevert(IError.OnlyOperatorCanCall.selector);
        ledger.executeSwapResultUpload(swapResultData, 1);
    }

    function test_swapResultUpload_zeroQuantities() public {
        // Setup initial deposits
        vm.prank(address(ledgerCrossChainManager));
        ledger.accountDeposit(usdcDepositData);
        
        vm.prank(address(ledgerCrossChainManager));
        ledger.accountDeposit(wethDepositData);

        // Create swap with zero quantities
        EventTypes.SwapResult memory zeroSwapData = EventTypes.SwapResult({
            accountId: ACCOUNT_ID,
            buyTokenHash: WETH_TOKEN_HASH,
            sellTokenHash: USDC_TOKEN_HASH,
            buyQuantity: 0,
            sellQuantity: 0,
            chainId: CHAIN_ID,
            swapStatus: 0
        });

        vm.prank(address(operatorManager));
        ledger.executeSwapResultUpload(zeroSwapData, 1);

        // Balances should remain unchanged
        assertEq(ledger.getUserLedgerBalance(ACCOUNT_ID, USDC_TOKEN_HASH), INITIAL_USDC_AMOUNT.toInt128());
        assertEq(ledger.getUserLedgerBalance(ACCOUNT_ID, WETH_TOKEN_HASH), INITIAL_WETH_AMOUNT.toInt128());
    }

    function test_swapResultUpload_sameToken() public {
        // Setup initial deposits
        vm.prank(address(ledgerCrossChainManager));
        ledger.accountDeposit(usdcDepositData);

        // Create swap with same buy and sell token (should be unusual but technically possible)
        EventTypes.SwapResult memory sameTokenSwapData = EventTypes.SwapResult({
            accountId: ACCOUNT_ID,
            buyTokenHash: USDC_TOKEN_HASH,
            sellTokenHash: USDC_TOKEN_HASH,
            buyQuantity: 100000, // 0.1 USDC (positive)
            sellQuantity: -100000,  // -0.1 USDC (negative for selling)
            chainId: CHAIN_ID,
            swapStatus: 0
        });

        vm.prank(address(operatorManager));
        ledger.executeSwapResultUpload(sameTokenSwapData, 1);

        // Balance should remain the same (buy and sell cancel out)
        assertEq(ledger.getUserLedgerBalance(ACCOUNT_ID, USDC_TOKEN_HASH), INITIAL_USDC_AMOUNT.toInt128());
    }

    // Event definition for testing
    event SwapResultUploaded(
        uint64 indexed eventId,
        bytes32 indexed accountId,
        bytes32 buyTokenHash,
        bytes32 sellTokenHash,
        int128 buyQuantity,
        int128 sellQuantity,
        uint256 chainId,
        uint8 swapStatus
    );
}

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
import ".././cheater/LedgerCheater.sol";
import "../../src/LedgerImplA.sol";
import "../../src/OperatorManagerImplA.sol";

contract TradeUploadTest is Test {
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
    bytes32 constant ACCOUNT_ID_1 = 0xa11ce00000000000000000000000000000000000000000000000000000000000;
    bytes32 constant ACCOUNT_ID_2 = 0xb0b0000000000000000000000000000000000000000000000000000000000000;
    bytes32 constant ACCOUNT_ID_3 = 0xccccc00000000000000000000000000000000000000000000000000000000000;
    bytes32 constant BROKER_HASH = 0x083098c593f395bea1de45dda552d9f14e8fcb0be3faaa7a1903c5477d7ba7fd; // woofi_dex
    bytes32 constant TOKEN_HASH = 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa; // USDC
    bytes32 constant SYMBOL_HASH_BTC_USDC = 0x1111101010101010101010101010101010101010101010101010101010101010;
    bytes32 constant SYMBOL_HASH_ETH_USDC = 0x2222101010101010101010101010101010101010101010101010101010101010;
    uint256 constant CHAIN_ID = 986532;

    // account 1 setup
    PerpTypes.FuturesTradeUpload tradeUpload1Setup = PerpTypes.FuturesTradeUpload(
        ACCOUNT_ID_1, SYMBOL_HASH_BTC_USDC, TOKEN_HASH, 11, 99, 90000000000, 100, 100, 1, 2, 3, false
    );
    // account 2 setup
    PerpTypes.FuturesTradeUpload tradeUpload2Setup = PerpTypes.FuturesTradeUpload(
        ACCOUNT_ID_2, SYMBOL_HASH_BTC_USDC, TOKEN_HASH, -12, -96, 80000000000, 100, 100, 4, 5, 6, true
    );
    // account 3 setup
    PerpTypes.FuturesTradeUpload tradeUpload3Setup = PerpTypes.FuturesTradeUpload(
        ACCOUNT_ID_3, SYMBOL_HASH_BTC_USDC, TOKEN_HASH, -13, -91, 70000000000, 100, 100, 2, 3, 4, true
    );
    // account 1 buy
    PerpTypes.FuturesTradeUpload tradeUploadA1 = PerpTypes.FuturesTradeUpload(
        ACCOUNT_ID_1, SYMBOL_HASH_BTC_USDC, TOKEN_HASH, 14, 84, 60000000000, 100, 100, 7, 8, 9, false
    );
    // account 1 sell
    PerpTypes.FuturesTradeUpload tradeUploadA2 = PerpTypes.FuturesTradeUpload(
        ACCOUNT_ID_1, SYMBOL_HASH_BTC_USDC, TOKEN_HASH, -15, -75, 50000000000, 100, 100, 10, 11, 12, true
    );
    // account 2 buy
    PerpTypes.FuturesTradeUpload tradeUploadB1 = PerpTypes.FuturesTradeUpload(
        ACCOUNT_ID_2, SYMBOL_HASH_BTC_USDC, TOKEN_HASH, 16, 64, 40000000000, 100, 100, 13, 14, 15, false
    );
    // account 2 sell
    PerpTypes.FuturesTradeUpload tradeUploadB2 = PerpTypes.FuturesTradeUpload(
        ACCOUNT_ID_2, SYMBOL_HASH_BTC_USDC, TOKEN_HASH, -17, -51, 30000000000, 100, 100, 16, 17, 18, true
    );
    // account 3 buy
    PerpTypes.FuturesTradeUpload tradeUploadC1 = PerpTypes.FuturesTradeUpload(
        ACCOUNT_ID_3, SYMBOL_HASH_BTC_USDC, TOKEN_HASH, 18, 36, 20000000000, 100, 100, 13, 14, 15, false
    );
    // account 3 sell
    PerpTypes.FuturesTradeUpload tradeUploadC2 = PerpTypes.FuturesTradeUpload(
        ACCOUNT_ID_3, SYMBOL_HASH_BTC_USDC, TOKEN_HASH, -19, -19, 10000000000, 100, 100, 16, 17, 18, true
    );

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
        OperatorManagerImplA operatorManagerImplA = new OperatorManagerImplA();

        ledger.setOperatorManagerAddress(address(operatorManager));
        ledger.setCrossChainManager(address(ledgerCrossChainManager));
        ledger.setVaultManager(address(vaultManager));
        ledger.setFeeManager(address(feeManager));
        ledger.setMarketManager(address(marketManager));
        ledger.setLedgerImplA(address(ledgerImplA));

        operatorManager.setOperator(operatorAddress);
        operatorManager.setLedger(address(ledger));
        operatorManager.setOperatorManagerImplA(address(operatorManagerImplA));

        vaultManager.setLedgerAddress(address(ledger));
        if (!vaultManager.getAllowedToken(TOKEN_HASH)) {
            vaultManager.setAllowedToken(TOKEN_HASH, true);
        }
        if (!vaultManager.getAllowedBroker(BROKER_HASH)) {
            vaultManager.setAllowedBroker(BROKER_HASH, true);
        }
        if (!vaultManager.getAllowedSymbol(SYMBOL_HASH_BTC_USDC)) {
            vaultManager.setAllowedSymbol(SYMBOL_HASH_BTC_USDC, true);
        }
        if (!vaultManager.getAllowedSymbol(SYMBOL_HASH_ETH_USDC)) {
            vaultManager.setAllowedSymbol(SYMBOL_HASH_ETH_USDC, true);
        }
        vaultManager.setAllowedChainToken(TOKEN_HASH, CHAIN_ID, true);

        feeManager.setLedgerAddress(address(ledger));

        marketManager.setOperatorManagerAddress(address(operatorManager));
        marketManager.setLedgerAddress(address(ledger));

        ledgerCrossChainManager.setLedger(address(ledger));
        ledgerCrossChainManager.setOperatorManager(address(operatorManager));

        // init some storage slots
        vm.startPrank(address(ledger));
        marketManager.setLastFundingUpdated(SYMBOL_HASH_BTC_USDC, 1);
        marketManager.setLastFundingUpdated(SYMBOL_HASH_ETH_USDC, 1);
        vm.stopPrank();
        vm.startPrank(address(operatorManager));
        ledger.executeProcessValidatedFutures(tradeUpload1Setup);
        ledger.executeProcessValidatedFutures(tradeUpload2Setup);
        ledger.executeProcessValidatedFutures(tradeUpload3Setup);
        vm.stopPrank();
    }

    function test_gasTracker_sameAccountUpload() public {
        vm.startPrank(address(operatorManager));
        uint256 gas1 = gasleft();
        ledger.executeProcessValidatedFutures(tradeUploadA1);
        uint256 gas2 = gasleft();
        ledger.executeProcessValidatedFutures(tradeUploadA1);
        uint256 gas3 = gasleft();
        ledger.executeProcessValidatedFutures(tradeUploadA2);
        uint256 gas4 = gasleft();

        uint256 gasUsedFirstUpload = gas1 - gas2;
        uint256 gasUsedSecondUpload = gas2 - gas3;
        uint256 gasUsedThirdUpload = gas3 - gas4;
        console2.log("Same account gasUsedFirstUpload (buy): ", gasUsedFirstUpload);
        console2.log("Same account gasUsedSecondUpload (buy): ", gasUsedSecondUpload);
        console2.log("Same account gasUsedThirdUpload (sell): ", gasUsedThirdUpload);
    }

    function test_gasTracker_sameAccountUpload_2() public {
        vm.startPrank(address(operatorManager));
        uint256 gas1 = gasleft();
        ledger.executeProcessValidatedFutures(tradeUploadA2);
        uint256 gas2 = gasleft();
        ledger.executeProcessValidatedFutures(tradeUploadA2);
        uint256 gas3 = gasleft();
        ledger.executeProcessValidatedFutures(tradeUploadA1);
        uint256 gas4 = gasleft();

        uint256 gasUsedFirstUpload = gas1 - gas2;
        uint256 gasUsedSecondUpload = gas2 - gas3;
        uint256 gasUsedThirdUpload = gas3 - gas4;
        console2.log("Same account gasUsedFirstUpload (sell): ", gasUsedFirstUpload);
        console2.log("Same account gasUsedSecondUpload (sell): ", gasUsedSecondUpload);
        console2.log("Same account gasUsedThirdUpload (buy): ", gasUsedThirdUpload);
    }

    function test_gasTracker_diffAccountUpload() public {
        vm.startPrank(address(operatorManager));
        uint256 gas1 = gasleft();
        ledger.executeProcessValidatedFutures(tradeUploadA1);
        uint256 gas2 = gasleft();
        ledger.executeProcessValidatedFutures(tradeUploadB1);
        uint256 gas3 = gasleft();
        ledger.executeProcessValidatedFutures(tradeUploadC1);
        uint256 gas4 = gasleft();
        ledger.executeProcessValidatedFutures(tradeUploadA1);
        uint256 gas5 = gasleft();
        ledger.executeProcessValidatedFutures(tradeUploadB1);
        uint256 gas6 = gasleft();
        ledger.executeProcessValidatedFutures(tradeUploadC1);
        uint256 gas7 = gasleft();
        ledger.executeProcessValidatedFutures(tradeUploadA2);
        uint256 gas8 = gasleft();
        ledger.executeProcessValidatedFutures(tradeUploadB2);
        uint256 gas9 = gasleft();
        ledger.executeProcessValidatedFutures(tradeUploadC2);
        uint256 gas10 = gasleft();
        ledger.executeProcessValidatedFutures(tradeUploadA1);
        uint256 gas11 = gasleft();
        ledger.executeProcessValidatedFutures(tradeUploadB1);
        uint256 gas12 = gasleft();
        ledger.executeProcessValidatedFutures(tradeUploadC1);
        uint256 gas13 = gasleft();

        uint256 gasUsedFirstUploadForA = gas1 - gas2;
        uint256 gasUsedFirstUploadForB = gas2 - gas3;
        uint256 gasUsedFirstUploadForC = gas3 - gas4;
        uint256 gasUsedSecondUploadForA = gas4 - gas5;
        uint256 gasUsedSecondUploadForB = gas5 - gas6;
        uint256 gasUsedSecondUploadForC = gas6 - gas7;
        uint256 gasUsedThirdUploadForA = gas7 - gas8;
        uint256 gasUsedThirdUploadForB = gas8 - gas9;
        uint256 gasUsedThirdUploadForC = gas9 - gas10;
        uint256 gasUsedFourthUploadForA = gas10 - gas11;
        uint256 gasUsedFourthUploadForB = gas11 - gas12;
        uint256 gasUsedFourthUploadForC = gas12 - gas13;
        console2.log("Diff account gasUsedFirstUpload (buy) for A: ", gasUsedFirstUploadForA);
        console2.log("Diff account gasUsedFirstUpload (buy) for B: ", gasUsedFirstUploadForB);
        console2.log("Diff account gasUsedFirstUpload (buy) for C: ", gasUsedFirstUploadForC);
        console2.log("Diff account gasUsedSecondUpload (buy) for A: ", gasUsedSecondUploadForA);
        console2.log("Diff account gasUsedSecondUpload (buy) for B: ", gasUsedSecondUploadForB);
        console2.log("Diff account gasUsedSecondUpload (buy) for C: ", gasUsedSecondUploadForC);
        console2.log("Diff account gasUsedThirdUpload (sell) for A: ", gasUsedThirdUploadForA);
        console2.log("Diff account gasUsedThirdUpload (sell) for B: ", gasUsedThirdUploadForB);
        console2.log("Diff account gasUsedThirdUpload (sell) for C: ", gasUsedThirdUploadForC);
        console2.log("Diff account gasUsedFourthUpload (buy) for A: ", gasUsedFourthUploadForA);
        console2.log("Diff account gasUsedFourthUpload (buy) for B: ", gasUsedFourthUploadForB);
        console2.log("Diff account gasUsedFourthUpload (buy) for C: ", gasUsedFourthUploadForC);
    }
}

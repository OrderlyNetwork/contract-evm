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

contract PerpTradeUploadTest is Test {
    bytes32 constant BROKER_HASH = 0x083098c593f395bea1de45dda552d9f14e8fcb0be3faaa7a1903c5477d7ba7fd;
    bytes32 constant TOKEN_HASH = 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa;
    bytes32 constant SYMBOL_HASH_ETH_USDC = 0x2222101010101010101010101010101010101010101010101010101010101010;
    uint256 constant CHAIN_ID = 986532;
    bytes32 constant ALICE = 0xa11ce00000000000000000000000000000000000000000000000000000000000;
    bytes32 constant BOB = 0xb0b0000000000000000000000000000000000000000000000000000000000000;
    bytes32 constant INSURANCE_FUND = 0x1234123412341234123412341234123412341234123412341234123412341234;

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

    function setUp() public {
        admin = new ProxyAdmin();

        ledgerCrossChainManager = new LedgerCrossChainManagerMock();

        IOperatorManager operatorManagerImpl = new OperatorManager();
        IVaultManager vaultManagerImpl = new VaultManager();
        ILedger ledgerImpl = new LedgerCheater();
        IFeeManager feeImpl = new FeeManager();
        IMarketManager marketImpl = new MarketManager();
        LedgerImplA ledgerImplA = new LedgerImplA();

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
        vaultManager.setAllowedSymbol(SYMBOL_HASH_ETH_USDC, true);

        feeManager.setLedgerAddress(address(ledger));

        marketManager.setOperatorManagerAddress(address(operatorManager));
        marketManager.setLedgerAddress(address(ledger));

        ledgerCrossChainManager.setLedger(address(ledger));
        ledgerCrossChainManager.setOperatorManager(address(operatorManager));
    }

    function test_perp_trade_init_holdings_zero() public {
        ledger.cheatDeposit(ALICE, TOKEN_HASH, 1000000000, CHAIN_ID);
        ledger.cheatDeposit(BOB, TOKEN_HASH, 1000000000, CHAIN_ID);

        vm.prank(address(operatorManager));
        ledger.executeProcessValidatedFutures({
            trade: PerpTypes.FuturesTradeUpload({
                tradeId: 13,
                matchId: 1678975214714862536,
                accountId: ALICE,
                symbolHash: SYMBOL_HASH_ETH_USDC,
                side: true,
                tradeQty: -200000000,
                sumUnitaryFundings: 1000000000000001,
                executedPrice: 250000000,
                notional: -5000000,
                fee: 7500,
                feeAssetHash: TOKEN_HASH,
                timestamp: 1678975214714
            })
        });

        vm.prank(address(operatorManager));
        ledger.executeProcessValidatedFutures({
            trade: PerpTypes.FuturesTradeUpload({
                tradeId: 14,
                matchId: 1678975214714862536,
                accountId: BOB,
                symbolHash: SYMBOL_HASH_ETH_USDC,
                side: false,
                tradeQty: 200000000,
                sumUnitaryFundings: 1000000000000001,
                executedPrice: 250000000,
                notional: 5000000,
                fee: 5000,
                feeAssetHash: TOKEN_HASH,
                timestamp: 1678975214714
            })
        });

        AccountTypes.PerpPosition memory positionA = ledger.getPerpPosition(ALICE, SYMBOL_HASH_ETH_USDC);
        AccountTypes.PerpPosition memory positionB = ledger.getPerpPosition(BOB, SYMBOL_HASH_ETH_USDC);

        assertEq(ledger.getUserLedgerBalance(ALICE, TOKEN_HASH), 1000000000);
        assertEq(positionA.positionQty, -200000000);
        assertEq(positionA.costPosition, -4992500);
        assertEq(positionA.lastSumUnitaryFundings, 1000000000000001);
        assertEq(positionA.lastExecutedPrice, 250000000);

        assertEq(ledger.getUserLedgerBalance(BOB, TOKEN_HASH), 1000000000);
        assertEq(positionB.positionQty, 200000000);
        assertEq(positionB.costPosition, 5005000);
        assertEq(positionB.lastSumUnitaryFundings, 1000000000000001);
        assertEq(positionB.lastExecutedPrice, 250000000);
    }

    function test_perp_trade_increase_positions() public {
        bytes32 feeCollectorHash = feeManager.getFeeCollector(IFeeManager.FeeCollectorType.FuturesFeeCollector);
        ledger.cheatDeposit(ALICE, TOKEN_HASH, 999992500, CHAIN_ID);
        ledger.cheatDeposit(BOB, TOKEN_HASH, 999995000, CHAIN_ID);
        ledger.cheatDeposit(feeCollectorHash, TOKEN_HASH, 12500, CHAIN_ID);
        ledger.cheatSetUserPosition(
            ALICE,
            SYMBOL_HASH_ETH_USDC,
            AccountTypes.PerpPosition({
                positionQty: -200000000,
                costPosition: -5000000,
                lastSumUnitaryFundings: 1000000000000001,
                lastExecutedPrice: 250000000,
                lastSettledPrice: 0,
                averageEntryPrice: 0,
                openingCost: 0,
                lastAdlPrice: 0
            })
        );
        ledger.cheatSetUserPosition(
            BOB,
            SYMBOL_HASH_ETH_USDC,
            AccountTypes.PerpPosition({
                positionQty: 200000000,
                costPosition: 5000000,
                lastSumUnitaryFundings: 1000000000000001,
                lastExecutedPrice: 250000000,
                lastSettledPrice: 0,
                averageEntryPrice: 0,
                openingCost: 0,
                lastAdlPrice: 0
            })
        );

        vm.prank(address(operatorManager));
        ledger.executeProcessValidatedFutures({
            trade: PerpTypes.FuturesTradeUpload({
                tradeId: 13,
                matchId: 1678975214714862536,
                accountId: ALICE,
                symbolHash: SYMBOL_HASH_ETH_USDC,
                side: true,
                tradeQty: -200000000,
                sumUnitaryFundings: 2000000000000002,
                executedPrice: 250000000,
                notional: -5000000,
                fee: 7500,
                feeAssetHash: TOKEN_HASH,
                timestamp: 1678975214714
            })
        });

        vm.prank(address(operatorManager));
        ledger.executeProcessValidatedFutures({
            trade: PerpTypes.FuturesTradeUpload({
                tradeId: 14,
                matchId: 1678975214714862536,
                accountId: BOB,
                symbolHash: SYMBOL_HASH_ETH_USDC,
                side: false,
                tradeQty: 200000000,
                sumUnitaryFundings: 2000000000000002,
                executedPrice: 250000000,
                notional: 5000000,
                fee: 5000,
                feeAssetHash: TOKEN_HASH,
                timestamp: 1678975214714
            })
        });

        AccountTypes.PerpPosition memory positionA = ledger.getPerpPosition(ALICE, SYMBOL_HASH_ETH_USDC);
        AccountTypes.PerpPosition memory positionB = ledger.getPerpPosition(BOB, SYMBOL_HASH_ETH_USDC);

        assertEq(ledger.getUserLedgerBalance(ALICE, TOKEN_HASH), 999992500);
        assertEq(positionA.positionQty, -400000000);
        assertEq(positionA.costPosition, -11992500);
        assertEq(positionA.lastSumUnitaryFundings, 2000000000000002);
        assertEq(positionA.lastExecutedPrice, 250000000);

        assertEq(ledger.getUserLedgerBalance(BOB, TOKEN_HASH), 999995000);
        assertEq(positionB.positionQty, 400000000);
        assertEq(positionB.costPosition, 12005001);
        assertEq(positionB.lastSumUnitaryFundings, 2000000000000002);
        assertEq(positionB.lastExecutedPrice, 250000000);

        assertEq(ledger.getUserLedgerBalance(feeCollectorHash, TOKEN_HASH), 12500);
    }

    function test_perp_trade_decrease_positions() public {
        ledger.cheatDeposit(ALICE, TOKEN_HASH, 999985000, CHAIN_ID);
        ledger.cheatDeposit(BOB, TOKEN_HASH, 999990000, CHAIN_ID);
        bytes32 feeCollectorHash = feeManager.getFeeCollector(IFeeManager.FeeCollectorType.FuturesFeeCollector);
        ledger.cheatDeposit(feeCollectorHash, TOKEN_HASH, 25000, CHAIN_ID);
        ledger.cheatSetUserPosition(
            ALICE,
            SYMBOL_HASH_ETH_USDC,
            AccountTypes.PerpPosition({
                positionQty: -400000000,
                costPosition: -8000000,
                lastSumUnitaryFundings: 2000000000000002,
                lastExecutedPrice: 250000000,
                lastSettledPrice: 0,
                averageEntryPrice: 0,
                openingCost: 0,
                lastAdlPrice: 0
            })
        );
        ledger.cheatSetUserPosition(
            BOB,
            SYMBOL_HASH_ETH_USDC,
            AccountTypes.PerpPosition({
                positionQty: 400000000,
                costPosition: 12000000,
                lastSumUnitaryFundings: 2000000000000002,
                lastExecutedPrice: 250000000,
                lastSettledPrice: 0,
                averageEntryPrice: 0,
                openingCost: 0,
                lastAdlPrice: 0
            })
        );

        vm.prank(address(operatorManager));
        ledger.executeProcessValidatedFutures({
            trade: PerpTypes.FuturesTradeUpload({
                tradeId: 13,
                matchId: 1678975214714862536,
                accountId: ALICE,
                symbolHash: SYMBOL_HASH_ETH_USDC,
                side: true,
                tradeQty: 200000000,
                sumUnitaryFundings: 3000000000000003,
                executedPrice: 250000000,
                notional: 5000000,
                fee: 7500,
                feeAssetHash: TOKEN_HASH,
                timestamp: 1678975214714
            })
        });

        vm.prank(address(operatorManager));
        ledger.executeProcessValidatedFutures({
            trade: PerpTypes.FuturesTradeUpload({
                tradeId: 14,
                matchId: 1678975214714862536,
                accountId: BOB,
                symbolHash: SYMBOL_HASH_ETH_USDC,
                side: false,
                tradeQty: -200000000,
                sumUnitaryFundings: 3000000000000003,
                executedPrice: 250000000,
                notional: -5000000,
                fee: 5000,
                feeAssetHash: TOKEN_HASH,
                timestamp: 1678975214714
            })
        });

        AccountTypes.PerpPosition memory positionA = ledger.getPerpPosition(ALICE, SYMBOL_HASH_ETH_USDC);
        AccountTypes.PerpPosition memory positionB = ledger.getPerpPosition(BOB, SYMBOL_HASH_ETH_USDC);

        assertEq(ledger.getUserLedgerBalance(ALICE, TOKEN_HASH), 999985000);
        assertEq(positionA.positionQty, -200000000);
        assertEq(positionA.costPosition, -6992500);
        assertEq(positionA.lastSumUnitaryFundings, 3000000000000003);
        assertEq(positionA.lastExecutedPrice, 250000000);

        assertEq(ledger.getUserLedgerBalance(BOB, TOKEN_HASH), 999990000);
        assertEq(positionB.positionQty, 200000000);
        assertEq(positionB.costPosition, 11005001);
        assertEq(positionB.lastSumUnitaryFundings, 3000000000000003);
        assertEq(positionB.lastExecutedPrice, 250000000);

        AccountTypes.PerpPosition memory positionF = ledger.getPerpPosition(feeCollectorHash, SYMBOL_HASH_ETH_USDC);
        assertEq(ledger.getUserLedgerBalance(feeCollectorHash, TOKEN_HASH), 25000);
        assertEq(positionF.positionQty, 0);
        assertEq(positionF.costPosition, -12500);
        assertEq(positionF.lastSumUnitaryFundings, 3000000000000003);
        assertEq(positionF.lastExecutedPrice, 0);
    }
}

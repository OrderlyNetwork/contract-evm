// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/OperatorManager.sol";
import "../../src/VaultManager.sol";
import "../../src/MarketManager.sol";
import "../mock/LedgerCrossChainManagerMock.sol";
import "../../src/FeeManager.sol";
import "../cheater/LedgerCheater.sol";
import "../../src/LedgerImplA.sol";
import "../../src/OperatorManagerImplA.sol";

// https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/578683884/Event+upload+-+Liquidation+Adl+change+2024-05
contract LiquidationNewTest is Test {
    bytes32 constant BROKER_HASH = 0x083098c593f395bea1de45dda552d9f14e8fcb0be3faaa7a1903c5477d7ba7fd;
    bytes32 constant TOKEN_HASH = 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa;
    bytes32 constant SYMBOL_HASH_BTC_USDC = 0x1111101010101010101010101010101010101010101010101010101010101010;
    bytes32 constant SYMBOL_HASH_ETH_USDC = 0x2222101010101010101010101010101010101010101010101010101010101010;
    uint256 constant CHAIN_ID = 986532;
    bytes32 constant LIQUIDATED_ACCOUNT_ID = 0xa11ce00000000000000000000000000000000000000000000000000000000000;
    bytes32 constant LIQUIDATOR_ACCOUNT_ID = 0xb0b0000000000000000000000000000000000000000000000000000000000000;
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
        OperatorManagerImplA operatorManagerImplA = new OperatorManagerImplA();

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
        marketManager.setPerpMarketCfg(
            SYMBOL_HASH_BTC_USDC,
            MarketTypes.PerpMarketCfg({
                baseMaintenanceMargin: 1,
                baseInitialMargin: 1,
                liquidationFeeMax: 1,
                markPrice: 1,
                indexPriceOrderly: 1,
                sumUnitaryFundings: 1,
                lastMarkPriceUpdated: 1,
                lastFundingUpdated: 1
            })
        );

        ledgerCrossChainManager.setLedger(address(ledger));
        ledgerCrossChainManager.setOperatorManager(address(operatorManager));
    }

    // MM
    function test_liquidation_new1() public {
        ledger.cheatSetUserPosition(
            LIQUIDATED_ACCOUNT_ID,
            SYMBOL_HASH_BTC_USDC,
            AccountTypes.PerpPosition({
                positionQty: -289_000_000,
                costPosition: -435_175_502,
                lastSumUnitaryFundings: 40_331_900_000_000_000,
                lastExecutedPrice: 200000000,
                lastSettledPrice: 0,
                averageEntryPrice: 15_057_975_848,
                openingCost: 1e8,
                lastAdlPrice: 0
            })
        );
        ledger.cheatSetUserPosition(
            LIQUIDATOR_ACCOUNT_ID,
            SYMBOL_HASH_BTC_USDC,
            AccountTypes.PerpPosition({
                positionQty: 4_059_000_000,
                costPosition: -2_533_031_349,
                lastSumUnitaryFundings: 40_376_000_000_000_000,
                lastExecutedPrice: 180000000000,
                lastSettledPrice: 0,
                averageEntryPrice: 6_240_530_547,
                openingCost: -1e8,
                lastAdlPrice: 0
            })
        );
        ledger.cheatSetUserPosition(
            INSURANCE_FUND,
            SYMBOL_HASH_BTC_USDC,
            AccountTypes.PerpPosition({
                positionQty: 0,
                costPosition: -142_229_490,
                lastSumUnitaryFundings: 40_376_000_000_000_000,
                lastExecutedPrice: 180000000000,
                lastSettledPrice: 0,
                averageEntryPrice: 0,
                openingCost: 0,
                lastAdlPrice: 0
            })
        );

        vm.prank(address(operatorManager));

        EventTypes.LiquidationTransfer[] memory liquidationTransfers = new EventTypes.LiquidationTransfer[](1);
        liquidationTransfers[0] = EventTypes.LiquidationTransfer({
            liquidationTransferId: 100,
            liquidatorAccountId: LIQUIDATOR_ACCOUNT_ID,
            symbolHash: SYMBOL_HASH_BTC_USDC,
            positionQtyTransfer: -254_000_000,
            costPositionTransfer: -402_465_540,
            liquidatorFee: 7_043_147,
            insuranceFee: 7_043_147,
            liquidationFee: 14_086_294,
            markPrice: 15_845_100_000,
            sumUnitaryFundings: 40_376_000_000_000_000
        });

        ledger.executeLiquidation({
            liquidation: EventTypes.Liquidation({
                liquidatedAccountId: LIQUIDATED_ACCOUNT_ID,
                insuranceAccountId: INSURANCE_FUND,
                insuranceTransferAmount: 0,
                liquidatedAssetHash: TOKEN_HASH,
                liquidationTransfers: liquidationTransfers,
                timestamp: 1672811225658
            }),
            eventId: 12000
        });

        AccountTypes.PerpPosition memory LiquidatedBtcPosition =
            ledger.getPerpPosition(LIQUIDATED_ACCOUNT_ID, SYMBOL_HASH_BTC_USDC);
        assertEq(LiquidatedBtcPosition.positionQty, -35_000_000);
        assertEq(LiquidatedBtcPosition.costPosition, -18_751_117);
        assertEq(LiquidatedBtcPosition.lastSumUnitaryFundings, 40_376_000_000_000_000);
        assertEq(LiquidatedBtcPosition.lastExecutedPrice, 15_845_100_000);
        // averageEntryPrice & openingCost is not provided by cefi, we just calculate it ourselves
        assertEq(LiquidatedBtcPosition.averageEntryPrice, 34602077);
        assertEq(LiquidatedBtcPosition.openingCost, 12110727);

        AccountTypes.PerpPosition memory LiquidatorBtcPosition =
            ledger.getPerpPosition(LIQUIDATOR_ACCOUNT_ID, SYMBOL_HASH_BTC_USDC);
        assertEq(LiquidatorBtcPosition.positionQty, 3_805_000_000);
        assertEq(LiquidatorBtcPosition.costPosition, -2_942_540_036);
        assertEq(LiquidatorBtcPosition.lastSumUnitaryFundings, 40_376_000_000_000_000);
        assertEq(LiquidatorBtcPosition.lastExecutedPrice, 15_845_100_000);
        // averageEntryPrice & openingCost is not provided by cefi, we just calculate it ourselves
        assertEq(LiquidatorBtcPosition.averageEntryPrice, 2463661);
        assertEq(LiquidatorBtcPosition.openingCost, -93742301);

        AccountTypes.PerpPosition memory InsuranceBtcPosition =
            ledger.getPerpPosition(INSURANCE_FUND, SYMBOL_HASH_BTC_USDC);
        assertEq(InsuranceBtcPosition.positionQty, 0);
        assertEq(InsuranceBtcPosition.costPosition, -149_272_637);
        assertEq(InsuranceBtcPosition.lastSumUnitaryFundings, 40_376_000_000_000_000);
        assertEq(InsuranceBtcPosition.lastExecutedPrice, 15_845_100_000);
    }

    // BANKRUPT
    function test_liquidation_new2() public {
        ledger.cheatDeposit(LIQUIDATED_ACCOUNT_ID, TOKEN_HASH, 131_043_979, CHAIN_ID);
        ledger.cheatDeposit(LIQUIDATOR_ACCOUNT_ID, TOKEN_HASH, 960_973_540_503, CHAIN_ID);
        ledger.cheatSetUserPosition(
            LIQUIDATED_ACCOUNT_ID,
            SYMBOL_HASH_BTC_USDC,
            AccountTypes.PerpPosition({
                positionQty: 137_030_000,
                costPosition: 4_292_900_523,
                lastSumUnitaryFundings: 548_310_000_000_000_000,
                lastExecutedPrice: 200000000,
                lastSettledPrice: 0,
                averageEntryPrice: 0,
                openingCost: 0,
                lastAdlPrice: 0
            })
        );
        ledger.cheatSetUserPosition(
            LIQUIDATED_ACCOUNT_ID,
            SYMBOL_HASH_ETH_USDC,
            AccountTypes.PerpPosition({
                positionQty: 0,
                costPosition: 3_690_505,
                lastSumUnitaryFundings: 304_849_000_000_000,
                lastExecutedPrice: 200000000,
                lastSettledPrice: 0,
                averageEntryPrice: 0,
                openingCost: 0,
                lastAdlPrice: 0
            })
        );
        ledger.cheatSetUserPosition(
            LIQUIDATOR_ACCOUNT_ID,
            SYMBOL_HASH_BTC_USDC,
            AccountTypes.PerpPosition({
                positionQty: 0,
                costPosition: -145_993_533,
                lastSumUnitaryFundings: 548_310_000_000_000_000,
                lastExecutedPrice: 200000000,
                lastSettledPrice: 0,
                averageEntryPrice: 0,
                openingCost: 0,
                lastAdlPrice: 0
            })
        );
        ledger.cheatSetUserPosition(
            LIQUIDATOR_ACCOUNT_ID,
            SYMBOL_HASH_ETH_USDC,
            AccountTypes.PerpPosition({
                positionQty: 0,
                costPosition: 1_182_048,
                lastSumUnitaryFundings: 304_849_000_000_000,
                lastExecutedPrice: 200000000,
                lastSettledPrice: 0,
                averageEntryPrice: 0,
                openingCost: 0,
                lastAdlPrice: 0
            })
        );

        vm.prank(address(operatorManager));

        EventTypes.LiquidationTransfer[] memory liquidationTransfers = new EventTypes.LiquidationTransfer[](2);
        liquidationTransfers[0] = EventTypes.LiquidationTransfer({
            liquidationTransferId: 100,
            liquidatorAccountId: LIQUIDATOR_ACCOUNT_ID,
            symbolHash: SYMBOL_HASH_BTC_USDC,
            positionQtyTransfer: 137_030_000,
            costPositionTransfer: 4_292_900_523,
            liquidatorFee: 0,
            insuranceFee: 0,
            liquidationFee: 0,
            markPrice: 307_368_000_000,
            sumUnitaryFundings: 548_310_000_000_000_000
        });
        liquidationTransfers[1] = EventTypes.LiquidationTransfer({
            liquidationTransferId: 100,
            liquidatorAccountId: LIQUIDATOR_ACCOUNT_ID,
            symbolHash: SYMBOL_HASH_ETH_USDC,
            positionQtyTransfer: 0,
            costPositionTransfer: 3_690_505,
            liquidatorFee: 0,
            insuranceFee: 0,
            liquidationFee: 0,
            markPrice: 110_120_000,
            sumUnitaryFundings: 304_849_000_000_000
        });

        ledger.executeLiquidation({
            liquidation: EventTypes.Liquidation({
                liquidatedAccountId: LIQUIDATED_ACCOUNT_ID,
                insuranceAccountId: LIQUIDATOR_ACCOUNT_ID,
                insuranceTransferAmount: 131_043_979,
                liquidatedAssetHash: TOKEN_HASH,
                liquidationTransfers: liquidationTransfers,
                timestamp: 1672811225658
            }),
            eventId: 12000
        });

        // liquidated account
        AccountTypes.PerpPosition memory LiquidatedBtcPosition =
            ledger.getPerpPosition(LIQUIDATED_ACCOUNT_ID, SYMBOL_HASH_BTC_USDC);
        assertEq(LiquidatedBtcPosition.positionQty, 0);
        assertEq(LiquidatedBtcPosition.costPosition, 0);
        assertEq(LiquidatedBtcPosition.lastSumUnitaryFundings, 0);
        assertEq(LiquidatedBtcPosition.lastExecutedPrice, 0);
        // because we delete position, so all values becomes 0s, otherwise will be:
        // assertEq(LiquidatedBtcPosition.lastSumUnitaryFundings, 548_310_000_000_000_000);
        // assertEq(LiquidatedBtcPosition.lastExecutedPrice, 307_368_000_000);
        AccountTypes.PerpPosition memory LiquidatedEthPosition =
            ledger.getPerpPosition(LIQUIDATED_ACCOUNT_ID, SYMBOL_HASH_ETH_USDC);
        assertEq(LiquidatedEthPosition.positionQty, 0);
        assertEq(LiquidatedEthPosition.costPosition, 0);
        assertEq(LiquidatedEthPosition.lastSumUnitaryFundings, 0);
        assertEq(LiquidatedEthPosition.lastExecutedPrice, 0);
        // because we delete position, so all values becomes 0s, otherwise will be:
        // assertEq(LiquidatedEthPosition.lastSumUnitaryFundings, 304_849_000_000_000);
        // assertEq(LiquidatedEthPosition.lastExecutedPrice, 110_120_000);
        uint128 liquidatedTokenBalance = ledger.getUserLedgerBalance(LIQUIDATED_ACCOUNT_ID, TOKEN_HASH);
        assertEq(liquidatedTokenBalance, 0);

        // liquidator account (same as insurance account)
        AccountTypes.PerpPosition memory LiquidatorBtcPosition =
            ledger.getPerpPosition(LIQUIDATOR_ACCOUNT_ID, SYMBOL_HASH_BTC_USDC);
        assertEq(LiquidatorBtcPosition.positionQty, 137_030_000);
        assertEq(LiquidatorBtcPosition.costPosition, 4_146_906_990);
        assertEq(LiquidatorBtcPosition.lastSumUnitaryFundings, 548_310_000_000_000_000);
        assertEq(LiquidatorBtcPosition.lastExecutedPrice, 307_368_000_000);
        AccountTypes.PerpPosition memory LiquidatorEthPosition =
            ledger.getPerpPosition(LIQUIDATOR_ACCOUNT_ID, SYMBOL_HASH_ETH_USDC);
        assertEq(LiquidatorEthPosition.positionQty, 0);
        assertEq(LiquidatorEthPosition.costPosition, 4_872_553);
        assertEq(LiquidatorEthPosition.lastSumUnitaryFundings, 304_849_000_000_000);
        assertEq(LiquidatorEthPosition.lastExecutedPrice, 110_120_000);
        uint128 liquidatorTokenBalance = ledger.getUserLedgerBalance(LIQUIDATOR_ACCOUNT_ID, TOKEN_HASH);
        assertEq(liquidatorTokenBalance, 961_104_584_482);
    }

    // CLAIM_FUND
    function test_liquidation_new3() public {
        ledger.cheatSetUserPosition(
            LIQUIDATED_ACCOUNT_ID,
            SYMBOL_HASH_BTC_USDC,
            AccountTypes.PerpPosition({
                positionQty: 10_423_000,
                costPosition: 7_189_159_164,
                lastSumUnitaryFundings: 8_590_900_000_000_000_000,
                lastExecutedPrice: 200000000,
                lastSettledPrice: 0,
                averageEntryPrice: 0,
                openingCost: 0,
                lastAdlPrice: 0
            })
        );
        ledger.cheatSetUserPosition(
            LIQUIDATOR_ACCOUNT_ID,
            SYMBOL_HASH_BTC_USDC,
            AccountTypes.PerpPosition({
                positionQty: -348_927_000,
                costPosition: -247_353_409_795,
                lastSumUnitaryFundings: 8_590_900_000_000_000_000,
                lastExecutedPrice: 200000000,
                lastSettledPrice: 0,
                averageEntryPrice: 7_088_973_045_790,
                openingCost: 1e8,
                lastAdlPrice: 0
            })
        );

        vm.prank(address(operatorManager));

        EventTypes.LiquidationTransfer[] memory liquidationTransfers = new EventTypes.LiquidationTransfer[](1);
        liquidationTransfers[0] = EventTypes.LiquidationTransfer({
            liquidationTransferId: 100,
            liquidatorAccountId: LIQUIDATOR_ACCOUNT_ID,
            symbolHash: SYMBOL_HASH_BTC_USDC,
            positionQtyTransfer: 10_423_000,
            costPositionTransfer: 6_606_754_049,
            liquidatorFee: 33_033_771,
            insuranceFee: 0,
            liquidationFee: 33_033_771,
            markPrice: 6_338_630_000_000,
            sumUnitaryFundings: 8_590_900_000_000_000_000
        });

        ledger.executeLiquidation({
            liquidation: EventTypes.Liquidation({
                liquidatedAccountId: LIQUIDATED_ACCOUNT_ID,
                insuranceAccountId: LIQUIDATED_ACCOUNT_ID,
                insuranceTransferAmount: 0,
                liquidatedAssetHash: TOKEN_HASH,
                liquidationTransfers: liquidationTransfers,
                timestamp: 1672811225658
            }),
            eventId: 12000
        });

        // liquidated account (same as insurance account)
        AccountTypes.PerpPosition memory LiquidatedBtcPosition =
            ledger.getPerpPosition(LIQUIDATED_ACCOUNT_ID, SYMBOL_HASH_BTC_USDC);
        assertEq(LiquidatedBtcPosition.positionQty, 0);
        assertEq(LiquidatedBtcPosition.costPosition, 615_438_886);
        assertEq(LiquidatedBtcPosition.lastSumUnitaryFundings, 8_590_900_000_000_000_000);
        assertEq(LiquidatedBtcPosition.lastExecutedPrice, 6_338_630_000_000);

        // liquidator account
        AccountTypes.PerpPosition memory LiquidatorBtcPosition =
            ledger.getPerpPosition(LIQUIDATOR_ACCOUNT_ID, SYMBOL_HASH_BTC_USDC);
        assertEq(LiquidatorBtcPosition.positionQty, -338_504_000);
        assertEq(LiquidatorBtcPosition.costPosition, -240_779_689_517);
        assertEq(LiquidatorBtcPosition.lastSumUnitaryFundings, 8_590_900_000_000_000_000);
        assertEq(LiquidatorBtcPosition.lastExecutedPrice, 6_338_630_000_000);
        assertEq(LiquidatorBtcPosition.averageEntryPrice, 28_659_290);
        assertEq(LiquidatorBtcPosition.openingCost, 97_012_842);
    }
}

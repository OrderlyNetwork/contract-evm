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

contract LiquidationTest is Test {
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

    function testLiquidation() public {
        ledger.cheatDeposit(LIQUIDATED_ACCOUNT_ID, TOKEN_HASH, 400000000, CHAIN_ID);
        ledger.cheatDeposit(LIQUIDATOR_ACCOUNT_ID, TOKEN_HASH, 100000000000, CHAIN_ID);
        ledger.cheatDeposit(INSURANCE_FUND, TOKEN_HASH, 1000000000000, CHAIN_ID);

        ledger.cheatSetUserPosition(
            LIQUIDATED_ACCOUNT_ID,
            SYMBOL_HASH_BTC_USDC,
            AccountTypes.PerpPosition({
                positionQty: -400000000,
                costPosition: -8000000,
                lastSumUnitaryFundings: 2000000000000002,
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
                positionQty: 200000000,
                costPosition: 3600000000,
                lastSumUnitaryFundings: 2000000000000002,
                lastExecutedPrice: 180000000000,
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
            positionQtyTransfer: -200000000,
            costPositionTransfer: -4000000,
            liquidatorFee: 15000,
            insuranceFee: 15000,
            liquidationFee: 30000,
            markPrice: 200000000,
            sumUnitaryFundings: 3000000000000003
        });
        liquidationTransfers[1] = EventTypes.LiquidationTransfer({
            liquidationTransferId: 101,
            liquidatorAccountId: LIQUIDATOR_ACCOUNT_ID,
            symbolHash: SYMBOL_HASH_ETH_USDC,
            positionQtyTransfer: 100000000,
            costPositionTransfer: 1800000000,
            liquidatorFee: 18000000,
            insuranceFee: 18000000,
            liquidationFee: 36000000,
            markPrice: 180000000000,
            sumUnitaryFundings: 3000000000000003
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
        assertEq(LiquidatedBtcPosition.positionQty, -200000000);
        assertEq(LiquidatedBtcPosition.costPosition, -7970000);
        assertEq(LiquidatedBtcPosition.lastSumUnitaryFundings, 3000000000000003);
        assertEq(LiquidatedBtcPosition.lastExecutedPrice, 200000000);

        AccountTypes.PerpPosition memory LiquidatedEthPosition =
            ledger.getPerpPosition(LIQUIDATED_ACCOUNT_ID, SYMBOL_HASH_ETH_USDC);
        assertEq(LiquidatedEthPosition.positionQty, 100000000);
        assertEq(LiquidatedEthPosition.costPosition, 1838000001);
        assertEq(LiquidatedEthPosition.lastSumUnitaryFundings, 3000000000000003);
        assertEq(LiquidatedEthPosition.lastExecutedPrice, 180000000000);

        uint128 liquidatedTokenBalance = ledger.getUserLedgerBalance(LIQUIDATED_ACCOUNT_ID, TOKEN_HASH);
        assertEq(liquidatedTokenBalance, 400000000);

        AccountTypes.PerpPosition memory LiquidatorBtcPosition =
            ledger.getPerpPosition(LIQUIDATOR_ACCOUNT_ID, SYMBOL_HASH_BTC_USDC);
        assertEq(LiquidatorBtcPosition.positionQty, -200000000);
        assertEq(LiquidatorBtcPosition.costPosition, -4015000);
        assertEq(LiquidatorBtcPosition.lastSumUnitaryFundings, 3000000000000003);
        assertEq(LiquidatorBtcPosition.lastExecutedPrice, 200000000);

        AccountTypes.PerpPosition memory LiquidatorEthPosition =
            ledger.getPerpPosition(LIQUIDATOR_ACCOUNT_ID, SYMBOL_HASH_ETH_USDC);
        assertEq(LiquidatorEthPosition.positionQty, 100000000);
        assertEq(LiquidatorEthPosition.costPosition, 1782000000);
        assertEq(LiquidatorEthPosition.lastSumUnitaryFundings, 3000000000000003);
        assertEq(LiquidatorEthPosition.lastExecutedPrice, 180000000000);

        uint128 liquidatorTokenBalance = ledger.getUserLedgerBalance(LIQUIDATOR_ACCOUNT_ID, TOKEN_HASH);
        assertEq(liquidatorTokenBalance, 100000000000);

        AccountTypes.PerpPosition memory InsuranceBtcPosition =
            ledger.getPerpPosition(INSURANCE_FUND, SYMBOL_HASH_BTC_USDC);
        assertEq(InsuranceBtcPosition.positionQty, -0);
        assertEq(InsuranceBtcPosition.costPosition, -15000);
        assertEq(InsuranceBtcPosition.lastSumUnitaryFundings, 3000000000000003);
        assertEq(InsuranceBtcPosition.lastExecutedPrice, 200000000);

        AccountTypes.PerpPosition memory InsuranceEthPosition =
            ledger.getPerpPosition(INSURANCE_FUND, SYMBOL_HASH_ETH_USDC);
        assertEq(InsuranceEthPosition.positionQty, 0);
        assertEq(InsuranceEthPosition.costPosition, -18000000);
        assertEq(InsuranceEthPosition.lastSumUnitaryFundings, 3000000000000003);
        assertEq(InsuranceEthPosition.lastExecutedPrice, 180000000000);

        uint128 insuranceTokenBalance = ledger.getUserLedgerBalance(INSURANCE_FUND, TOKEN_HASH);
        assertEq(insuranceTokenBalance, 1000000000000);
    }

    function testLiquidatorIsInsuranceFund() public {
        ledger.cheatDeposit(LIQUIDATED_ACCOUNT_ID, TOKEN_HASH, 1000, CHAIN_ID);
        ledger.cheatDeposit(INSURANCE_FUND, TOKEN_HASH, 1000000000000, CHAIN_ID);

        ledger.cheatSetUserPosition(
            LIQUIDATED_ACCOUNT_ID,
            SYMBOL_HASH_BTC_USDC,
            AccountTypes.PerpPosition({
                positionQty: -400000000,
                costPosition: -8000000,
                lastSumUnitaryFundings: 3000000000000003,
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
                positionQty: 200000000,
                costPosition: 3600000000,
                lastSumUnitaryFundings: 3000000000000003,
                lastExecutedPrice: 180000000000,
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
            liquidatorAccountId: INSURANCE_FUND,
            symbolHash: SYMBOL_HASH_BTC_USDC,
            positionQtyTransfer: -400000000,
            costPositionTransfer: -8000000,
            liquidatorFee: 0,
            insuranceFee: 0,
            liquidationFee: 0,
            markPrice: 250000000,
            sumUnitaryFundings: 3000000000000003
        });
        liquidationTransfers[1] = EventTypes.LiquidationTransfer({
            liquidationTransferId: 101,
            liquidatorAccountId: INSURANCE_FUND,
            symbolHash: SYMBOL_HASH_ETH_USDC,
            positionQtyTransfer: 200000000,
            costPositionTransfer: 3600000000,
            liquidatorFee: 0,
            insuranceFee: 0,
            liquidationFee: 0,
            markPrice: 150000000000,
            sumUnitaryFundings: 3000000000000003
        });

        ledger.executeLiquidation({
            liquidation: EventTypes.Liquidation({
                liquidatedAccountId: LIQUIDATED_ACCOUNT_ID,
                insuranceAccountId: INSURANCE_FUND,
                insuranceTransferAmount: 1000,
                liquidatedAssetHash: TOKEN_HASH,
                liquidationTransfers: liquidationTransfers,
                timestamp: 1672811225658
            }),
            eventId: 12000
        });

        AccountTypes.PerpPosition memory LiquidatedBtcPosition =
            ledger.getPerpPosition(LIQUIDATED_ACCOUNT_ID, SYMBOL_HASH_BTC_USDC);
        assertEq(LiquidatedBtcPosition.positionQty, 0);
        assertEq(LiquidatedBtcPosition.costPosition, 0);
        assertEq(LiquidatedBtcPosition.lastSumUnitaryFundings, 0);
        assertEq(LiquidatedBtcPosition.lastExecutedPrice, 0);

        AccountTypes.PerpPosition memory LiquidatedEthPosition =
            ledger.getPerpPosition(LIQUIDATED_ACCOUNT_ID, SYMBOL_HASH_ETH_USDC);
        assertEq(LiquidatedEthPosition.positionQty, 0);
        assertEq(LiquidatedEthPosition.costPosition, 0);
        assertEq(LiquidatedEthPosition.lastSumUnitaryFundings, 0);
        assertEq(LiquidatedEthPosition.lastExecutedPrice, 0);

        uint128 liquidatedTokenBalance = ledger.getUserLedgerBalance(LIQUIDATED_ACCOUNT_ID, TOKEN_HASH);
        assertEq(liquidatedTokenBalance, 0);

        AccountTypes.PerpPosition memory LiquidatorBtcPosition =
            ledger.getPerpPosition(INSURANCE_FUND, SYMBOL_HASH_BTC_USDC);
        assertEq(LiquidatorBtcPosition.positionQty, -400000000);
        assertEq(LiquidatorBtcPosition.costPosition, -8000000);
        assertEq(LiquidatorBtcPosition.lastSumUnitaryFundings, 3000000000000003);
        assertEq(LiquidatorBtcPosition.lastExecutedPrice, 250000000);

        AccountTypes.PerpPosition memory LiquidatorEthPosition =
            ledger.getPerpPosition(INSURANCE_FUND, SYMBOL_HASH_ETH_USDC);
        assertEq(LiquidatorEthPosition.positionQty, 200000000);
        assertEq(LiquidatorEthPosition.costPosition, 3600000000);
        assertEq(LiquidatorEthPosition.lastSumUnitaryFundings, 3000000000000003);
        assertEq(LiquidatorEthPosition.lastExecutedPrice, 150000000000);

        uint128 liquidatorTokenBalance = ledger.getUserLedgerBalance(INSURANCE_FUND, TOKEN_HASH);
        assertEq(liquidatorTokenBalance, 1000000001000);
    }

    function testLiquidatorIsInsuranceFundTwoStages() public {
        ledger.cheatDeposit(LIQUIDATED_ACCOUNT_ID, TOKEN_HASH, 1000, CHAIN_ID);
        ledger.cheatDeposit(INSURANCE_FUND, TOKEN_HASH, 1000000000000, CHAIN_ID);

        ledger.cheatSetUserPosition(
            LIQUIDATED_ACCOUNT_ID,
            SYMBOL_HASH_BTC_USDC,
            AccountTypes.PerpPosition({
                positionQty: -400000000,
                costPosition: -8000000,
                lastSumUnitaryFundings: 1000000000000001,
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
                positionQty: 200000000,
                costPosition: 3600000000,
                lastSumUnitaryFundings: 1000000000000001,
                lastExecutedPrice: 180000000000,
                lastSettledPrice: 0,
                averageEntryPrice: 0,
                openingCost: 0,
                lastAdlPrice: 0
            })
        );
        vm.prank(address(operatorManager));

        EventTypes.LiquidationTransfer[] memory firstLiquidationTransfers = new EventTypes.LiquidationTransfer[](2);
        firstLiquidationTransfers[0] = EventTypes.LiquidationTransfer({
            liquidationTransferId: 100,
            liquidatorAccountId: INSURANCE_FUND,
            symbolHash: SYMBOL_HASH_BTC_USDC,
            positionQtyTransfer: -200000000,
            costPositionTransfer: -2000000,
            liquidatorFee: 0,
            insuranceFee: 0,
            liquidationFee: 0,
            markPrice: 250000000,
            sumUnitaryFundings: 2000000000000002
        });
        firstLiquidationTransfers[1] = EventTypes.LiquidationTransfer({
            liquidationTransferId: 101,
            liquidatorAccountId: INSURANCE_FUND,
            symbolHash: SYMBOL_HASH_ETH_USDC,
            positionQtyTransfer: 100000000,
            costPositionTransfer: 1800000000,
            liquidatorFee: 0,
            insuranceFee: 0,
            liquidationFee: 0,
            markPrice: 150000000000,
            sumUnitaryFundings: 2000000000000002
        });

        ledger.executeLiquidation({
            liquidation: EventTypes.Liquidation({
                liquidatedAccountId: LIQUIDATED_ACCOUNT_ID,
                insuranceAccountId: INSURANCE_FUND,
                insuranceTransferAmount: 500,
                liquidatedAssetHash: TOKEN_HASH,
                liquidationTransfers: firstLiquidationTransfers,
                timestamp: 1672811225658
            }),
            eventId: 12000
        });

        vm.prank(address(operatorManager));
        EventTypes.LiquidationTransfer[] memory secondLiquidationTransfers = new EventTypes.LiquidationTransfer[](2);
        secondLiquidationTransfers[0] = EventTypes.LiquidationTransfer({
            liquidationTransferId: 100,
            liquidatorAccountId: INSURANCE_FUND,
            symbolHash: SYMBOL_HASH_BTC_USDC,
            positionQtyTransfer: -200000000,
            costPositionTransfer: -4000000,
            liquidatorFee: 0,
            insuranceFee: 0,
            liquidationFee: 0,
            markPrice: 250000000,
            sumUnitaryFundings: 3000000000000003
        });
        secondLiquidationTransfers[1] = EventTypes.LiquidationTransfer({
            liquidationTransferId: 101,
            liquidatorAccountId: INSURANCE_FUND,
            symbolHash: SYMBOL_HASH_ETH_USDC,
            positionQtyTransfer: 100000000,
            costPositionTransfer: 1800000000,
            liquidatorFee: 0,
            insuranceFee: 0,
            liquidationFee: 0,
            markPrice: 150000000000,
            sumUnitaryFundings: 3000000000000003
        });

        ledger.executeLiquidation({
            liquidation: EventTypes.Liquidation({
                liquidatedAccountId: LIQUIDATED_ACCOUNT_ID,
                insuranceAccountId: INSURANCE_FUND,
                insuranceTransferAmount: 500,
                liquidatedAssetHash: TOKEN_HASH,
                liquidationTransfers: secondLiquidationTransfers,
                timestamp: 1672811225658
            }),
            eventId: 12001
        });

        AccountTypes.PerpPosition memory LiquidatedBtcPosition =
            ledger.getPerpPosition(LIQUIDATED_ACCOUNT_ID, SYMBOL_HASH_BTC_USDC);
        assertEq(LiquidatedBtcPosition.positionQty, 0);
        assertEq(LiquidatedBtcPosition.costPosition, -8000000);
        assertEq(LiquidatedBtcPosition.lastSumUnitaryFundings, 3000000000000003);
        assertEq(LiquidatedBtcPosition.lastExecutedPrice, 250000000);

        AccountTypes.PerpPosition memory LiquidatedEthPosition =
            ledger.getPerpPosition(LIQUIDATED_ACCOUNT_ID, SYMBOL_HASH_ETH_USDC);
        assertEq(LiquidatedEthPosition.positionQty, 0);
        assertEq(LiquidatedEthPosition.costPosition, 3000002);
        assertEq(LiquidatedEthPosition.lastSumUnitaryFundings, 3000000000000003);
        assertEq(LiquidatedEthPosition.lastExecutedPrice, 150000000000);

        uint128 liquidatedTokenBalance = ledger.getUserLedgerBalance(LIQUIDATED_ACCOUNT_ID, TOKEN_HASH);
        assertEq(liquidatedTokenBalance, 0);

        AccountTypes.PerpPosition memory LiquidatorBtcPosition =
            ledger.getPerpPosition(INSURANCE_FUND, SYMBOL_HASH_BTC_USDC);
        assertEq(LiquidatorBtcPosition.positionQty, -400000000);
        assertEq(LiquidatorBtcPosition.costPosition, -8000000);
        assertEq(LiquidatorBtcPosition.lastSumUnitaryFundings, 3000000000000003);
        assertEq(LiquidatorBtcPosition.lastExecutedPrice, 250000000);

        AccountTypes.PerpPosition memory LiquidatorEthPosition =
            ledger.getPerpPosition(INSURANCE_FUND, SYMBOL_HASH_ETH_USDC);
        assertEq(LiquidatorEthPosition.positionQty, 200000000);
        assertEq(LiquidatorEthPosition.costPosition, 3601000001);
        assertEq(LiquidatorEthPosition.lastSumUnitaryFundings, 3000000000000003);
        assertEq(LiquidatorEthPosition.lastExecutedPrice, 150000000000);

        uint128 liquidatorTokenBalance = ledger.getUserLedgerBalance(INSURANCE_FUND, TOKEN_HASH);
        assertEq(liquidatorTokenBalance, 1000000001000);
    }
}

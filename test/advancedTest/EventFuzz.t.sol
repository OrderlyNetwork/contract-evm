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

contract SettlementTest is Test {
    using SafeCastHelper for *;

    bytes32 constant BROKER_HASH = 0x083098c593f395bea1de45dda552d9f14e8fcb0be3faaa7a1903c5477d7ba7fd;
    bytes32 constant TOKEN_HASH = 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa;
    bytes32 constant SYMBOL_HASH_BTC_USDC = 0x1111101010101010101010101010101010101010101010101010101010101010;
    bytes32 constant SYMBOL_HASH_ETH_USDC = 0x2222101010101010101010101010101010101010101010101010101010101010;
    uint256 constant CHAIN_ID = 986532;
    bytes32 constant ALICE = 0xa11ce00000000000000000000000000000000000000000000000000000000000;
    bytes32 constant BOB = 0xb0b0000000000000000000000000000000000000000000000000000000000000;
    bytes32 constant LIQUIDATED_ACCOUNT_ID = ALICE;
    bytes32 constant LIQUIDATOR_ACCOUNT_ID = BOB;
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

        ledgerCrossChainManager.setLedger(address(ledger));
        ledgerCrossChainManager.setOperatorManager(address(operatorManager));

        ledger.cheatDeposit(ALICE, TOKEN_HASH, 1_000_000_000, CHAIN_ID);
        ledger.cheatDeposit(BOB, TOKEN_HASH, 1_000_000_000, CHAIN_ID);
        ledger.cheatDeposit(INSURANCE_FUND, TOKEN_HASH, 10_000_000_000, CHAIN_ID);
    }

    function testFuzz_settlement_1(int128 settleAmount, uint128 markPrice) public {
        vm.assume(settleAmount.abs() < 1_000_000_000);
        {
            EventTypes.SettlementExecution[] memory executions = new EventTypes.SettlementExecution[](1);
            executions[0] = EventTypes.SettlementExecution({
                symbolHash: SYMBOL_HASH_ETH_USDC,
                sumUnitaryFundings: 20_000_000_000_000_000,
                markPrice: markPrice,
                settledAmount: settleAmount
            });
            vm.prank(address(operatorManager));
            ledger.executeSettlement({
                settlement: EventTypes.Settlement({
                    accountId: ALICE,
                    settledAmount: settleAmount,
                    settledAssetHash: TOKEN_HASH,
                    insuranceAccountId: 0x0,
                    insuranceTransferAmount: 0,
                    settlementExecutions: executions,
                    timestamp: 0
                }),
                eventId: 1
            });
        }
        {
            EventTypes.SettlementExecution[] memory executions = new EventTypes.SettlementExecution[](1);
            executions[0] = EventTypes.SettlementExecution({
                symbolHash: SYMBOL_HASH_ETH_USDC,
                sumUnitaryFundings: 20_000_000_000_000_000,
                markPrice: markPrice,
                settledAmount: -settleAmount
            });
            vm.prank(address(operatorManager));
            ledger.executeSettlement({
                settlement: EventTypes.Settlement({
                    accountId: BOB,
                    settledAmount: -settleAmount,
                    settledAssetHash: TOKEN_HASH,
                    insuranceAccountId: 0x0,
                    insuranceTransferAmount: 0,
                    settlementExecutions: executions,
                    timestamp: 0
                }),
                eventId: 1
            });
        }
        // check total balance of Alice & Bob should be 1_000_000_000 * 2
        assertEq(
            ledger.getUserLedgerBalance(ALICE, TOKEN_HASH) + ledger.getUserLedgerBalance(BOB, TOKEN_HASH),
            1_000_000_000 * 2
        );
    }

    function testFuzz_settlement_2(int128 settleAmount, uint128 markPrice, uint128 insuranceTransferAmount) public {
        vm.assume(settleAmount.abs() < 1_000_000_000);
        vm.assume(insuranceTransferAmount < settleAmount.abs());
        {
            EventTypes.SettlementExecution[] memory executions = new EventTypes.SettlementExecution[](1);
            executions[0] = EventTypes.SettlementExecution({
                symbolHash: SYMBOL_HASH_ETH_USDC,
                sumUnitaryFundings: 20_000_000_000_000_000,
                markPrice: markPrice,
                settledAmount: settleAmount
            });
            vm.prank(address(operatorManager));
            ledger.executeSettlement({
                settlement: EventTypes.Settlement({
                    accountId: ALICE,
                    settledAmount: settleAmount,
                    settledAssetHash: TOKEN_HASH,
                    insuranceAccountId: INSURANCE_FUND,
                    insuranceTransferAmount: insuranceTransferAmount,
                    settlementExecutions: executions,
                    timestamp: 0
                }),
                eventId: 1
            });
        }
        {
            EventTypes.SettlementExecution[] memory executions = new EventTypes.SettlementExecution[](1);
            executions[0] = EventTypes.SettlementExecution({
                symbolHash: SYMBOL_HASH_ETH_USDC,
                sumUnitaryFundings: 20_000_000_000_000_000,
                markPrice: markPrice,
                settledAmount: -settleAmount
            });
            vm.prank(address(operatorManager));
            ledger.executeSettlement({
                settlement: EventTypes.Settlement({
                    accountId: BOB,
                    settledAmount: -settleAmount,
                    settledAssetHash: TOKEN_HASH,
                    insuranceAccountId: INSURANCE_FUND,
                    insuranceTransferAmount: insuranceTransferAmount,
                    settlementExecutions: executions,
                    timestamp: 0
                }),
                eventId: 1
            });
        }
        // check total balance of Alice & Bob & InsuranceFund should be 1_000_000_000 * 2 + 10_000_000_000
        assertEq(
            ledger.getUserLedgerBalance(ALICE, TOKEN_HASH) + ledger.getUserLedgerBalance(BOB, TOKEN_HASH)
                + ledger.getUserLedgerBalance(INSURANCE_FUND, TOKEN_HASH),
            1_000_000_000 * 2 + 10_000_000_000
        );
    }

    function testFuzz_liquidationV2_1(int128 positionQtyTransfer, int128 costPositionTransfer) public {
        vm.assume(positionQtyTransfer > 0);
        vm.assume(positionQtyTransfer < 1_000_000_000);
        vm.assume(costPositionTransfer > 0);
        vm.assume(costPositionTransfer < 1_000_000_000);
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

        vm.startPrank(address(operatorManager));

        EventTypes.LiquidationTransferV2[] memory liquidationTransfers1 = new EventTypes.LiquidationTransferV2[](1);
        liquidationTransfers1[0] = EventTypes.LiquidationTransferV2({
            symbolHash: SYMBOL_HASH_BTC_USDC,
            positionQtyTransfer: positionQtyTransfer,
            costPositionTransfer: costPositionTransfer,
            fee: 14_086_294,
            markPrice: 15_845_100_000,
            sumUnitaryFundings: 40_376_000_000_000_000
        });
        EventTypes.LiquidationTransferV2[] memory liquidationTransfers2 = new EventTypes.LiquidationTransferV2[](1);
        liquidationTransfers2[0] = EventTypes.LiquidationTransferV2({
            symbolHash: SYMBOL_HASH_BTC_USDC,
            positionQtyTransfer: -positionQtyTransfer,
            costPositionTransfer: -costPositionTransfer,
            fee: -7_043_147,
            markPrice: 15_845_100_000,
            sumUnitaryFundings: 40_376_000_000_000_000
        });
        EventTypes.LiquidationTransferV2[] memory liquidationTransfers3 = new EventTypes.LiquidationTransferV2[](1);
        liquidationTransfers3[0] = EventTypes.LiquidationTransferV2({
            symbolHash: SYMBOL_HASH_BTC_USDC,
            positionQtyTransfer: 0,
            costPositionTransfer: 0,
            fee: -7_043_147,
            markPrice: 15_845_100_000,
            sumUnitaryFundings: 40_376_000_000_000_000
        });

        ledger.executeLiquidationV2({
            liquidation: EventTypes.LiquidationV2({
                accountId: LIQUIDATED_ACCOUNT_ID,
                insuranceTransferAmount: 0,
                liquidatedAssetHash: TOKEN_HASH,
                liquidationTransfers: liquidationTransfers1,
                timestamp: 1672811225658,
                isInsuranceAccount: false
            }),
            eventId: 12000
        });
        ledger.executeLiquidationV2({
            liquidation: EventTypes.LiquidationV2({
                accountId: LIQUIDATOR_ACCOUNT_ID,
                insuranceTransferAmount: 0,
                liquidatedAssetHash: TOKEN_HASH,
                liquidationTransfers: liquidationTransfers2,
                timestamp: 1672811225658,
                isInsuranceAccount: false
            }),
            eventId: 12001
        });
        ledger.executeLiquidationV2({
            liquidation: EventTypes.LiquidationV2({
                accountId: INSURANCE_FUND,
                insuranceTransferAmount: 0,
                liquidatedAssetHash: TOKEN_HASH,
                liquidationTransfers: liquidationTransfers3,
                timestamp: 1672811225658,
                isInsuranceAccount: false
            }),
            eventId: 12002
        });

        vm.stopPrank();

        AccountTypes.PerpPosition memory LiquidatedBtcPosition =
            ledger.getPerpPosition(LIQUIDATED_ACCOUNT_ID, SYMBOL_HASH_BTC_USDC);
        assertEq(LiquidatedBtcPosition.lastSumUnitaryFundings, 40_376_000_000_000_000);
        assertEq(LiquidatedBtcPosition.lastExecutedPrice, 15_845_100_000);

        AccountTypes.PerpPosition memory LiquidatorBtcPosition =
            ledger.getPerpPosition(LIQUIDATOR_ACCOUNT_ID, SYMBOL_HASH_BTC_USDC);
        assertEq(LiquidatorBtcPosition.lastSumUnitaryFundings, 40_376_000_000_000_000);
        assertEq(LiquidatorBtcPosition.lastExecutedPrice, 15_845_100_000);

        AccountTypes.PerpPosition memory InsuranceBtcPosition =
            ledger.getPerpPosition(INSURANCE_FUND, SYMBOL_HASH_BTC_USDC);
        assertEq(InsuranceBtcPosition.positionQty, 0);
        assertEq(InsuranceBtcPosition.costPosition, -149_272_637);
        assertEq(InsuranceBtcPosition.lastSumUnitaryFundings, 40_376_000_000_000_000);
        assertEq(InsuranceBtcPosition.lastExecutedPrice, 15_845_100_000);
    }
}

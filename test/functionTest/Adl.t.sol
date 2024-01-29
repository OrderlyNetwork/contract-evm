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

contract AdlTest is Test {
    bytes32 constant BROKER_HASH = 0x083098c593f395bea1de45dda552d9f14e8fcb0be3faaa7a1903c5477d7ba7fd;
    bytes32 constant TOKEN_HASH = 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa;
    bytes32 constant SYMBOL_HASH_BTC_USDC = 0x1111101010101010101010101010101010101010101010101010101010101010;
    bytes32 constant SYMBOL_HASH_ETH_USDC = 0x2222101010101010101010101010101010101010101010101010101010101010;
    uint256 constant CHAIN_ID = 986532;
    bytes32 constant ALICE = 0xa11ce00000000000000000000000000000000000000000000000000000000000;
    bytes32 constant BOB = 0xb0b0000000000000000000000000000000000000000000000000000000000000;
    bytes32 constant CHARLIE = 0x0300000000000000000000000000000000000000000000000000000000000000;
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

        ledger.cheatDeposit(ALICE, TOKEN_HASH, 1_000_000_000, CHAIN_ID);
        ledger.cheatDeposit(BOB, TOKEN_HASH, 1_000_000_000, CHAIN_ID);
        ledger.cheatDeposit(CHARLIE, TOKEN_HASH, 1_000_000_000, CHAIN_ID);
        ledger.cheatDeposit(INSURANCE_FUND, TOKEN_HASH, 10_000_000_000, CHAIN_ID);

        ledger.cheatSetUserPosition(
            INSURANCE_FUND,
            SYMBOL_HASH_ETH_USDC,
            AccountTypes.PerpPosition({
                positionQty: 2_000_000_000,
                costPosition: 100_000_000,
                lastSumUnitaryFundings: 10_000_000_000_000_000,
                lastExecutedPrice: 20_000_000,
                lastSettledPrice: 0,
                averageEntryPrice: 2_000_000_000,
                openingCost: 0,
                lastAdlPrice: 20_000_000
            })
        );

        ledger.cheatSetUserPosition(
            INSURANCE_FUND,
            SYMBOL_HASH_BTC_USDC,
            AccountTypes.PerpPosition({
                positionQty: -2_000_000_000,
                costPosition: 100_000_000,
                lastSumUnitaryFundings: 10_000_000_000_000_000,
                lastExecutedPrice: 30_000_000,
                lastSettledPrice: 0,
                averageEntryPrice: 30_000_000,
                openingCost: 0,
                lastAdlPrice: 30_000_000
            })
        );

        ledger.cheatSetUserPosition(
            BOB,
            SYMBOL_HASH_ETH_USDC,
            AccountTypes.PerpPosition({
                positionQty: -1_000_000_000,
                costPosition: 100_000_000,
                lastSumUnitaryFundings: 10_000_000_000_000_000,
                lastExecutedPrice: 20_000_000,
                lastSettledPrice: 0,
                averageEntryPrice: 2_000_000_000,
                openingCost: 0,
                lastAdlPrice: 20_000_000
            })
        );

        ledger.cheatSetUserPosition(
            BOB,
            SYMBOL_HASH_BTC_USDC,
            AccountTypes.PerpPosition({
                positionQty: 1_000_000_000,
                costPosition: 100_000_000,
                lastSumUnitaryFundings: 10_000_000_000_000_000,
                lastExecutedPrice: 30_000_000,
                lastSettledPrice: 0,
                averageEntryPrice: 3_000_000_000,
                openingCost: 0,
                lastAdlPrice: 30_000_000
            })
        );

        ledger.cheatSetUserPosition(
            CHARLIE,
            SYMBOL_HASH_ETH_USDC,
            AccountTypes.PerpPosition({
                positionQty: -500_000_000,
                costPosition: 100_000_000,
                lastSumUnitaryFundings: 10_000_000_000_000_000,
                lastExecutedPrice: 20_000_000,
                lastSettledPrice: 0,
                averageEntryPrice: 2_000_000_000,
                openingCost: 0,
                lastAdlPrice: 20_000_000
            })
        );
    }

    function test_insuranceFundAdlPositivePosition() public {
        vm.prank(address(operatorManager));
        ledger.executeAdl({
            adl: EventTypes.Adl({
                accountId: BOB,
                insuranceAccountId: INSURANCE_FUND,
                symbolHash: SYMBOL_HASH_ETH_USDC,
                positionQtyTransfer: 1_000_000_000,
                costPositionTransfer: 100_000_000,
                adlPrice: 30_000_000,
                sumUnitaryFundings: 20_000_000_000_000_000,
                timestamp: 0
            }),
            eventId: 1
        });

        AccountTypes.PerpPosition memory bobEthPosition = ledger.getPerpPosition(BOB, SYMBOL_HASH_ETH_USDC);
        AccountTypes.PerpPosition memory insuranceFundEthPosition =
            ledger.getPerpPosition(INSURANCE_FUND, SYMBOL_HASH_ETH_USDC);

        assertEq(bobEthPosition.costPosition, 100_000_000);
        assertEq(bobEthPosition.lastExecutedPrice, 30_000_000);
        assertEq(bobEthPosition.lastAdlPrice, 30_000_000);
        assertEq(bobEthPosition.lastSumUnitaryFundings, 20_000_000_000_000_000);

        assertEq(bobEthPosition.positionQty, 0);
        assertEq(bobEthPosition.averageEntryPrice, 0);
        assertEq(ledger.getUserLedgerLastEngineEventId(BOB), 1);

        assertEq(insuranceFundEthPosition.costPosition, 200_000_000);
        assertEq(insuranceFundEthPosition.lastExecutedPrice, 30_000_000);
        assertEq(insuranceFundEthPosition.lastAdlPrice, 30_000_000);
        assertEq(insuranceFundEthPosition.lastSumUnitaryFundings, 20_000_000_000_000_000);

        assertEq(insuranceFundEthPosition.positionQty, 1_000_000_000);
        // assertEq(insuranceFundEthPosition.averageEntryPrice, 0);
        assertEq(ledger.getUserLedgerLastEngineEventId(INSURANCE_FUND), 1);
    }

    function test_insuranceFundAdlNegativePosition() public {
        vm.prank(address(operatorManager));
        ledger.executeAdl({
            adl: EventTypes.Adl({
                accountId: BOB,
                insuranceAccountId: INSURANCE_FUND,
                symbolHash: SYMBOL_HASH_BTC_USDC,
                positionQtyTransfer: -1_000_000_000,
                costPositionTransfer: -100_000_000,
                adlPrice: 40_000_000,
                sumUnitaryFundings: 20_000_000_000_000_000,
                timestamp: 0
            }),
            eventId: 1
        });

        AccountTypes.PerpPosition memory bobBtcPosition = ledger.getPerpPosition(BOB, SYMBOL_HASH_BTC_USDC);
        AccountTypes.PerpPosition memory insuranceFundBtcPosition =
            ledger.getPerpPosition(INSURANCE_FUND, SYMBOL_HASH_BTC_USDC);

        assertEq(bobBtcPosition.costPosition, 100_000_000);
        assertEq(bobBtcPosition.lastExecutedPrice, 40_000_000);
        assertEq(bobBtcPosition.lastAdlPrice, 40_000_000);
        assertEq(bobBtcPosition.lastSumUnitaryFundings, 20_000_000_000_000_000);

        assertEq(bobBtcPosition.positionQty, 0);
        assertEq(bobBtcPosition.averageEntryPrice, 0);
        assertEq(ledger.getUserLedgerLastEngineEventId(BOB), 1);

        assertEq(insuranceFundBtcPosition.costPosition, 0);
        assertEq(insuranceFundBtcPosition.lastExecutedPrice, 40_000_000);
        assertEq(insuranceFundBtcPosition.lastAdlPrice, 40_000_000);
        assertEq(insuranceFundBtcPosition.lastSumUnitaryFundings, 20_000_000_000_000_000);

        assertEq(insuranceFundBtcPosition.positionQty, -1_000_000_000);
        // assertEq(insuranceFundEthPosition.averageEntryPrice, 0);
        assertEq(ledger.getUserLedgerLastEngineEventId(INSURANCE_FUND), 1);
    }

    function testRevert_insuranceFundAdlLessPosition() public {
        vm.prank(address(operatorManager));
        vm.expectRevert(abi.encodeWithSelector(IError.InsurancePositionQtyInvalid.selector, 1000000000, -500000000));
        ledger.executeAdl({
            adl: EventTypes.Adl({
                accountId: CHARLIE,
                insuranceAccountId: INSURANCE_FUND,
                symbolHash: SYMBOL_HASH_ETH_USDC,
                positionQtyTransfer: 1_000_000_000,
                costPositionTransfer: -100_000_000,
                adlPrice: 40_000_000,
                sumUnitaryFundings: 20_000_000_000_000_000,
                timestamp: 0
            }),
            eventId: 1
        });
    }

    function testRevert_insuranceFundAdlEmptyPosition() public {
        vm.prank(address(operatorManager));
        vm.expectRevert(
            abi.encodeWithSelector(
                IError.UserPerpPositionQtyZero.selector,
                0xa11ce00000000000000000000000000000000000000000000000000000000000,
                0x2222101010101010101010101010101010101010101010101010101010101010
            )
        );
        ledger.executeAdl({
            adl: EventTypes.Adl({
                accountId: ALICE,
                insuranceAccountId: INSURANCE_FUND,
                symbolHash: SYMBOL_HASH_ETH_USDC,
                positionQtyTransfer: 1_000_000_000,
                costPositionTransfer: -100_000_000,
                adlPrice: 40_000_000,
                sumUnitaryFundings: 20_000_000_000_000_000,
                timestamp: 0
            }),
            eventId: 1
        });
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import "../../src/OperatorManager.sol";
import "../../src/VaultManager.sol";
import "../../src/MarketManager.sol";
import "../mock/LedgerCrossChainManagerMock.sol";
import "../../src/FeeManager.sol";
import "../cheater/LedgerCheater.sol";
import "../../src/LedgerImplA.sol";
import "../../src/OperatorManagerImplA.sol";
import "../../src/LedgerImplC.sol";

// https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/578683884/Event+upload+-+Liquidation+Adl+change+2024-05
contract BalanceTransferTest is Test {
    using SafeCast for uint256;
    using SafeCastHelper for uint128;

    bytes32 constant BROKER_HASH = 0x083098c593f395bea1de45dda552d9f14e8fcb0be3faaa7a1903c5477d7ba7fd;
    bytes32 constant TOKEN_HASH = 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa;
    uint256 constant CHAIN_ID = 986532;
    bytes32 constant ALICE = 0xa11ce00000000000000000000000000000000000000000000000000000000000;
    bytes32 constant BOB = 0xb0b0000000000000000000000000000000000000000000000000000000000000;
    bytes32 constant CHARLIE = 0x0300000000000000000000000000000000000000000000000000000000000000;
    uint256 constant btIdA2B = uint256(keccak256("alice"));
    uint128 constant amountA2B = 1_000_000_000;
    uint256 constant btIdB2C = uint256(keccak256("bob"));
    uint128 constant amountB2A = 1_000_000_000;
    uint256 constant btIdC2A = uint256(keccak256("charlie"));
    uint128 constant amountC2A = 1_000_000_000;

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
        LedgerImplC ledgerImplC = new LedgerImplC();

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
        ledger.setLedgerImplC(address(ledgerImplC));

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

        vaultManager.setAllowedChainToken(TOKEN_HASH, CHAIN_ID, true);

        feeManager.setLedgerAddress(address(ledger));

        marketManager.setOperatorManagerAddress(address(operatorManager));
        marketManager.setLedgerAddress(address(ledger));

        ledgerCrossChainManager.setLedger(address(ledger));
        ledgerCrossChainManager.setOperatorManager(address(operatorManager));
        ledger.cheatDeposit(ALICE, TOKEN_HASH, amountA2B + 1, CHAIN_ID);
    }

    function test_credit() public {
        EventTypes.BalanceTransfer memory bt = EventTypes.BalanceTransfer({
            fromAccountId: ALICE,
            toAccountId: BOB,
            amount: amountA2B,
            tokenHash: TOKEN_HASH,
            isFromAccountId: false,
            transferType: 0,
            transferId: btIdA2B
        });

        assertEq(ledger.getUserLedgerBalance(ALICE, TOKEN_HASH), (amountA2B + 1).toInt128());
        vm.prank(address(operatorManager));
        ledger.executeBalanceTransfer(bt, 123);

        assertEq(ledger.getUserLedgerBalance(ALICE, TOKEN_HASH), (amountA2B + 1).toInt128());
        assertEq(ledger.getUserLedgerBalance(BOB, TOKEN_HASH), amountA2B.toInt128());
        assertEq(ledger.cheatGetUserEscrowBalance(BOB, TOKEN_HASH), amountA2B);
    }

    function testRevert_withdraw() public {}

    function test_debit() public {
        EventTypes.BalanceTransfer memory bt = EventTypes.BalanceTransfer({
            fromAccountId: ALICE,
            toAccountId: BOB,
            amount: amountA2B,
            tokenHash: TOKEN_HASH,
            isFromAccountId: true,
            transferType: 0,
            transferId: btIdA2B
        });

        vm.prank(address(operatorManager));
        ledger.executeBalanceTransfer(bt, 123);

        assertEq(ledger.getUserLedgerBalance(ALICE, TOKEN_HASH), 1);
        assertEq(ledger.cheatGetUserEscrowBalance(BOB, TOKEN_HASH), 0);
    }
}

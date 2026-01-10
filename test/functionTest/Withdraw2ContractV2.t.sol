// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/OperatorManager.sol";
import "../../src/VaultManager.sol";
import "../../src/MarketManager.sol";
import "../mock/LedgerCrossChainManagerMock.sol";
import "../mock/LedgerCrossChainManagerV2Mock.sol";
import "../../src/FeeManager.sol";
import "../cheater/LedgerCheater.sol";
import "../../src/interface/error/IError.sol";
import "../../src/LedgerImplA.sol";
import "../../src/LedgerImplD.sol";
import "../../src/OperatorManagerImplA.sol";

// https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/578683884/Event+upload+-+Liquidation+Adl+change+2024-05
contract Withdraw2ContractV2 is Test {
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
    LedgerCrossChainManagerV2Mock ledgerCrossChainManagerV2;
    IOperatorManager operatorManager;
    VaultManager vaultManager;
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
        ledgerCrossChainManagerV2 = new LedgerCrossChainManagerV2Mock();

        IOperatorManager operatorManagerImpl = new OperatorManager();
        IVaultManager vaultManagerImpl = new VaultManager();
        ILedger ledgerImpl = new LedgerCheater();
        IFeeManager feeImpl = new FeeManager();
        IMarketManager marketImpl = new MarketManager();
        LedgerImplA ledgerImplA = new LedgerImplA();
        LedgerImplD ledgerImplD = new LedgerImplD();
        OperatorManagerImplA operatorManagerImplA = new OperatorManagerImplA();

        bytes memory initData = abi.encodeWithSignature("initialize()");
        operatorProxy = new TransparentUpgradeableProxy(address(operatorManagerImpl), address(admin), initData);
        vaultProxy = new TransparentUpgradeableProxy(address(vaultManagerImpl), address(admin), initData);
        ledgerProxy = new TransparentUpgradeableProxy(address(ledgerImpl), address(admin), initData);
        feeProxy = new TransparentUpgradeableProxy(address(feeImpl), address(admin), initData);
        marketProxy = new TransparentUpgradeableProxy(address(marketImpl), address(admin), initData);

        operatorManager = IOperatorManager(address(operatorProxy));
        vaultManager = VaultManager(address(vaultProxy));
        ledger = LedgerCheater(address(ledgerProxy));
        feeManager = IFeeManager(address(feeProxy));
        marketManager = IMarketManager(address(marketProxy));

        ledger.setOperatorManagerAddress(address(operatorManager));
        ledger.setCrossChainManager(address(ledgerCrossChainManager));
        ledger.setVaultManager(address(vaultManager));
        ledger.setFeeManager(address(feeManager));
        ledger.setMarketManager(address(marketManager));
        ledger.setLedgerImplA(address(ledgerImplA));
        ledger.setLedgerImplD(address(ledgerImplD));

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

        

        ledger.setLedgerImplD(address(ledgerImplD));
        ledger.setCrossChainManager(address(ledgerCrossChainManager));
        ledger.setCrossChainManagerV2(address(ledgerCrossChainManagerV2));
        ledgerCrossChainManager.setLedger(address(ledger));

    }

    function test_withdraw_solana_ceffu() public {
        EventTypes.Withdraw2ContractV2 memory data = EventTypes.Withdraw2ContractV2({
            brokerHash: 0x6ca2f644ef7bd6d75953318c7f2580014941e753b3c6d54da56b3bf75dd14dfc,
            tokenAmount: 12345,
            fee: 0,
            accountId: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed63,
            chainId: 10086,
            sender: Utils.toBytes32(0x6a9961Ace9bF0C1B8B98ba11558A4125B1f5EA3f),
            receiver: 0x0fb9ba52b1f09445f1e3a7508d59f0797923acf744fbe2da303fb06da859ee87,
            withdrawNonce: 9,
            timestamp: 1683270380530,
            vaultType: EventTypes.VaultEnum.Ceffu,
            senderChainType: EventTypes.ChainType.EVM,
            receiverChainType: EventTypes.ChainType.SOL,
            tokenHash: 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa,
            clientId: 0
        });
        uint64 eventId = 1;
        vaultManager.setAllowedChainToken(data.tokenHash, data.chainId, true);
        // vm.prank(ledger.owner());
        ledger.setSolanaPrimeWallet(0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed63, 0x0fb9ba52b1f09445f1e3a7508d59f0797923acf744fbe2da303fb06da859ee87);
        ledger.cheatDeposit(data.accountId, data.tokenHash, data.tokenAmount, data.chainId);
        vm.prank(address(operatorManager));
        ledger.executeWithdraw2ContractV2(data, eventId);

    }

    function test_withdraw_solana_ceffu_failed() public {
        EventTypes.Withdraw2ContractV2 memory data = _getWithdraw2ContractV2Data();
        uint64 eventId = 1;
        vaultManager.setAllowedChainToken(data.tokenHash, data.chainId, true);
        // vm.prank(ledger.owner());
        ledger.setSolanaPrimeWallet(0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed63, 0x0fb9ba52b1f09445f1e3a7508d59f0797923acf744fbe2da303fb06da859ee87);
        ledger.cheatDeposit(data.accountId, data.tokenHash, data.tokenAmount, data.chainId);

        vm.startPrank(address(operatorManager));
        {   
            data = _getWithdraw2ContractV2Data();
            data.brokerHash = keccak256("another broker");
            vm.expectRevert(IError.BrokerNotAllowed.selector);
            ledger.executeWithdraw2ContractV2(data, eventId);
        }

        {
            data = _getWithdraw2ContractV2Data();
            data.tokenHash = keccak256("another token");
            vm.expectRevert(abi.encodeWithSelector(IError.TokenNotAllowed.selector, data.tokenHash, data.chainId));
            ledger.executeWithdraw2ContractV2(data, eventId);
        }

        {
            data = _getWithdraw2ContractV2Data();
            data.receiver = bytes32(0);
            vm.expectRevert(IError.WithdrawToAddressZero.selector);
            ledger.executeWithdraw2ContractV2(data, eventId);
        }

        {
            data = _getWithdraw2ContractV2Data();
            data.receiver = keccak256("another solana prime wallet");
            vm.expectRevert(IError.InvalidPrimeWallet.selector);
            ledger.executeWithdraw2ContractV2(data, eventId);
        }

        {
            data = _getWithdraw2ContractV2Data();
            data.vaultType = EventTypes.VaultEnum.UserVault;
            vm.expectRevert(IError.NotImplemented.selector);
            ledger.executeWithdraw2ContractV2(data, eventId);
        }

        {
            data = _getWithdraw2ContractV2Data();
            data.tokenAmount += 1;
            vm.expectRevert(abi.encodeWithSelector(IError.WithdrawBalanceNotEnough.selector, data.tokenAmount - 1, data.tokenAmount));
            ledger.executeWithdraw2ContractV2(data, eventId);
        }

        {
            data = _getWithdraw2ContractV2Data();
            ledger.cheatSubVaultBalance(data.tokenHash, data.fee + 1, data.chainId);
            vm.expectRevert(abi.encodeWithSelector(IError.WithdrawVaultBalanceNotEnough.selector, data.tokenAmount - (data.fee + 1), data.tokenAmount - data.fee));
            ledger.executeWithdraw2ContractV2(data, eventId);
        }

        vm.stopPrank();

         {
            data = _getWithdraw2ContractV2Data();
            vm.prank(vaultManager.owner());
            
            vaultManager.setMaxWithdrawFee(data.tokenHash, data.fee + 1);
            uint128 maxFee = vaultManager.getMaxWithdrawFee(data.tokenHash);
            data.fee += 2;
            vm.prank(address(operatorManager));
            vm.expectRevert(abi.encodeWithSelector(IError.WithdrawFeeTooLarge.selector, maxFee, data.fee));
            ledger.executeWithdraw2ContractV2(data, eventId);
        }

        {
            data = _getWithdraw2ContractV2Data();
            ledger.cheatUserWithdrawNonce(data.accountId, data.withdrawNonce + 1);
            vm.expectEmit();
            vm.prank(address(operatorManager));
            emit ILedgerEvent.AccountWithdrawSolFail(
                data.accountId,
                data.withdrawNonce,
                1,
                data.senderChainType,
                data.receiverChainType,
                data.brokerHash,
                data.sender,
                data.receiver,
                data.chainId,
                data.tokenHash,
                data.tokenAmount,
                data.fee,
                101
            ) ;
            ledger.executeWithdraw2ContractV2(data, eventId);
            ledger.cheatUserWithdrawNonce(data.accountId, data.withdrawNonce - 1);
        }

        {
            data = _getWithdraw2ContractV2Data();
            ledger.cheatUserEscrowBalance(data.accountId, data.tokenHash, 1);
            vm.expectEmit();
            vm.prank(address(operatorManager));
            emit ILedgerEvent.AccountWithdrawSolFail(
                data.accountId,
                data.withdrawNonce,
                2,
                data.senderChainType,
                data.receiverChainType,
                data.brokerHash,
                data.sender,
                data.receiver,
                data.chainId,
                data.tokenHash,
                data.tokenAmount,
                data.fee,
                9
            ) ;
            ledger.executeWithdraw2ContractV2(data, eventId);
            
        }
    }

    function _getWithdraw2ContractV2Data() public pure returns (EventTypes.Withdraw2ContractV2 memory) {
        EventTypes.Withdraw2ContractV2 memory data = EventTypes.Withdraw2ContractV2({
            brokerHash: 0x6ca2f644ef7bd6d75953318c7f2580014941e753b3c6d54da56b3bf75dd14dfc,
            tokenAmount: 12345,
            fee: 0,
            accountId: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed63,
            chainId: 10086,
            sender: Utils.toBytes32(0x6a9961Ace9bF0C1B8B98ba11558A4125B1f5EA3f),
            receiver: 0x0fb9ba52b1f09445f1e3a7508d59f0797923acf744fbe2da303fb06da859ee87,
            withdrawNonce: 9,
            timestamp: 1683270380530,
            vaultType: EventTypes.VaultEnum.Ceffu,
            senderChainType: EventTypes.ChainType.EVM,
            receiverChainType: EventTypes.ChainType.SOL,
            tokenHash: 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa,
            clientId: 0
        });

        return data;
    }
    
}

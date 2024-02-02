// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "./dataLayout/LedgerDataLayout.sol";
import "./interface/ILedger.sol";
import "./interface/IVaultManager.sol";
import "./interface/ILedgerCrossChainManager.sol";
import "./interface/IMarketManager.sol";
import "./interface/IFeeManager.sol";
import "./interface/ILedgerImplA.sol";
import "./library/Utils.sol";
import "./library/Signature.sol";
import "./library/typesHelper/AccountTypeHelper.sol";
import "./library/typesHelper/AccountTypePositionHelper.sol";
import "./library/typesHelper/SafeCastHelper.sol";

/// @title Ledger contract, implementation part A contract, for resolve EIP170 limit
/// @author Orderly_Rubick
contract LedgerImplA is ILedgerImplA, OwnableUpgradeable, LedgerDataLayout {
    using AccountTypeHelper for AccountTypes.Account;
    using AccountTypePositionHelper for AccountTypes.PerpPosition;
    using SafeCastHelper for *;

    constructor() {
        _disableInitializers();
    }

    function initialize() external override initializer {
        __Ownable_init();
    }

    /// Interface implementation

    /// @notice The cross chain manager will call this function to notify the deposit event to the Ledger contract
    /// @param data account deposit data
    function accountDeposit(AccountTypes.AccountDeposit calldata data) external override {
        // validate data first
        if (!vaultManager.getAllowedBroker(data.brokerHash)) revert BrokerNotAllowed();
        if (!vaultManager.getAllowedChainToken(data.tokenHash, data.srcChainId)) {
            revert TokenNotAllowed(data.tokenHash, data.srcChainId);
        }
        if (!Utils.validateAccountId(data.accountId, data.brokerHash, data.userAddress)) revert AccountIdInvalid();

        // a not registerd account can still deposit, because of the consistency
        AccountTypes.Account storage account = userLedger[data.accountId];
        if (account.userAddress == address(0)) {
            // register account first
            account.userAddress = data.userAddress;
            account.brokerHash = data.brokerHash;
            // emit register event
            emit AccountRegister(data.accountId, data.brokerHash, data.userAddress);
        }
        account.addBalance(data.tokenHash, data.tokenAmount);
        vaultManager.addBalance(data.tokenHash, data.srcChainId, data.tokenAmount);
        uint64 tmpGlobalEventId = _newGlobalEventId(); // gas saving
        account.lastDepositEventId = tmpGlobalEventId;
        // emit deposit event
        emit AccountDeposit(
            data.accountId,
            _newGlobalDepositId(),
            tmpGlobalEventId,
            data.userAddress,
            data.tokenHash,
            data.tokenAmount,
            data.srcChainId,
            data.srcChainDepositNonce,
            data.brokerHash
        );
    }

    function executeProcessValidatedFutures(PerpTypes.FuturesTradeUpload calldata trade) external override {
        // validate data first
        if (!vaultManager.getAllowedSymbol(trade.symbolHash)) revert SymbolNotAllowed();
        // do the logic part
        AccountTypes.Account storage account = userLedger[trade.accountId];
        AccountTypes.PerpPosition storage perpPosition = account.perpPositions[trade.symbolHash];
        perpPosition.chargeFundingFee(trade.sumUnitaryFundings);
        perpPosition.calAverageEntryPrice(trade.tradeQty, trade.executedPrice.toInt128(), 0);
        perpPosition.positionQty += trade.tradeQty;
        perpPosition.costPosition += trade.notional;
        perpPosition.lastExecutedPrice = trade.executedPrice;
        // fee_swap_position
        _feeSwapPosition(perpPosition, trade.symbolHash, trade.fee, trade.tradeId, trade.sumUnitaryFundings);
        account.lastPerpTradeId = trade.tradeId;
        // update last funding update timestamp
        marketManager.setLastFundingUpdated(trade.symbolHash, trade.timestamp);
        // emit event
        emit ProcessValidatedFutures(
            trade.accountId,
            trade.symbolHash,
            trade.feeAssetHash,
            trade.tradeQty,
            trade.notional,
            trade.executedPrice,
            trade.fee,
            trade.sumUnitaryFundings,
            trade.tradeId,
            trade.matchId,
            trade.timestamp,
            trade.side
        );
    }

    function executeWithdrawAction(EventTypes.WithdrawData calldata withdraw, uint64 eventId) external override {
        bytes32 brokerHash = Utils.calculateStringHash(withdraw.brokerId);
        bytes32 tokenHash = Utils.calculateStringHash(withdraw.tokenSymbol);
        if (!vaultManager.getAllowedBroker(brokerHash)) revert BrokerNotAllowed();
        if (!vaultManager.getAllowedChainToken(tokenHash, withdraw.chainId)) {
            revert TokenNotAllowed(tokenHash, withdraw.chainId);
        }
        if (!Utils.validateAccountId(withdraw.accountId, brokerHash, withdraw.sender)) revert AccountIdInvalid();
        AccountTypes.Account storage account = userLedger[withdraw.accountId];
        uint8 state = 0;
        {
            // avoid stack too deep
            uint128 maxWithdrawFee = vaultManager.getMaxWithdrawFee(tokenHash);
            // https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/326402549/Withdraw+Error+Code
            if (account.lastWithdrawNonce >= withdraw.withdrawNonce) {
                // require withdraw nonce inc
                state = 101;
            } else if (account.balances[tokenHash] < withdraw.tokenAmount) {
                // require balance enough
                state = 1;
            } else if (vaultManager.getBalance(tokenHash, withdraw.chainId) < withdraw.tokenAmount - withdraw.fee) {
                // require chain has enough balance
                state = 2;
            } else if (!Signature.verifyWithdraw(withdraw.sender, withdraw)) {
                // require signature verify
                state = 4;
            } else if (maxWithdrawFee > 0 && maxWithdrawFee < withdraw.fee) {
                // require fee not exceed maxWithdrawFee
                state = 5;
            } else if (withdraw.receiver == address(0)) {
                // require receiver not zero address
                state = 6;
            }
        }
        // check all assert, should not change any status
        if (state != 0) {
            emit AccountWithdrawFail(
                withdraw.accountId,
                withdraw.withdrawNonce,
                _newGlobalEventId(),
                brokerHash,
                withdraw.sender,
                withdraw.receiver,
                withdraw.chainId,
                tokenHash,
                withdraw.tokenAmount,
                withdraw.fee,
                state
            );
            return;
        }
        // update status, should never fail
        // frozen balance
        // account should frozen `tokenAmount`, and vault should frozen `tokenAmount - fee`, because vault will payout `tokenAmount - fee`
        account.frozenBalance(withdraw.withdrawNonce, tokenHash, withdraw.tokenAmount);
        vaultManager.frozenBalance(tokenHash, withdraw.chainId, withdraw.tokenAmount - withdraw.fee);
        account.lastEngineEventId = eventId;
        // emit withdraw approve event
        emit AccountWithdrawApprove(
            withdraw.accountId,
            withdraw.withdrawNonce,
            _newGlobalEventId(),
            brokerHash,
            withdraw.sender,
            withdraw.receiver,
            withdraw.chainId,
            tokenHash,
            withdraw.tokenAmount,
            withdraw.fee
        );
        // send cross-chain tx
        ILedgerCrossChainManager(crossChainManagerAddress).withdraw(withdraw);
    }

    function accountWithDrawFinish(AccountTypes.AccountWithdraw calldata withdraw) external override {
        AccountTypes.Account storage account = userLedger[withdraw.accountId];
        // finish frozen balance
        account.finishFrozenBalance(withdraw.withdrawNonce, withdraw.tokenHash, withdraw.tokenAmount);
        vaultManager.finishFrozenBalance(withdraw.tokenHash, withdraw.chainId, withdraw.tokenAmount - withdraw.fee);
        // withdraw fee
        if (withdraw.fee > 0) {
            // gas saving if no fee
            bytes32 feeCollectorAccountId =
                feeManager.getFeeCollector(IFeeManager.FeeCollectorType.WithdrawFeeCollector);
            AccountTypes.Account storage feeCollectorAccount = userLedger[feeCollectorAccountId];
            feeCollectorAccount.addBalance(withdraw.tokenHash, withdraw.fee);
        }
        // emit withdraw finish event
        emit AccountWithdrawFinish(
            withdraw.accountId,
            withdraw.withdrawNonce,
            _newGlobalEventId(),
            withdraw.brokerHash,
            withdraw.sender,
            withdraw.receiver,
            withdraw.chainId,
            withdraw.tokenHash,
            withdraw.tokenAmount,
            withdraw.fee
        );
    }

    function executeSettlement(EventTypes.Settlement calldata settlement, uint64 eventId) external override {
        // check total settle amount zero
        int128 totalSettleAmount = 0;
        // gas saving
        uint256 length = settlement.settlementExecutions.length;
        EventTypes.SettlementExecution[] calldata settlementExecutions = settlement.settlementExecutions;
        AccountTypes.Account storage account = userLedger[settlement.accountId];
        if (settlement.insuranceTransferAmount != 0) {
            if (settlement.accountId == settlement.insuranceAccountId) revert InsuranceTransferToSelf();
            uint128 balance = account.balances[settlement.settledAssetHash];
            // transfer insurance fund
            if (
                balance.toInt128() + settlement.insuranceTransferAmount.toInt128() + settlement.settledAmount < 0
                    || settlement.insuranceTransferAmount > settlement.settledAmount.abs()
            ) {
                // overflow
                revert InsuranceTransferAmountInvalid(
                    balance, settlement.insuranceTransferAmount, settlement.settledAmount
                );
            }
            AccountTypes.Account storage insuranceFund = userLedger[settlement.insuranceAccountId];
            insuranceFund.subBalance(settlement.settledAssetHash, settlement.insuranceTransferAmount);
            account.addBalance(settlement.settledAssetHash, settlement.insuranceTransferAmount);
        }
        // for-loop ledger execution
        for (uint256 i = 0; i < length; ++i) {
            EventTypes.SettlementExecution calldata ledgerExecution = settlementExecutions[i];
            totalSettleAmount += ledgerExecution.settledAmount;
            if (!vaultManager.getAllowedSymbol(ledgerExecution.symbolHash)) revert SymbolNotAllowed();
            AccountTypes.PerpPosition storage position = account.perpPositions[ledgerExecution.symbolHash];
            position.chargeFundingFee(ledgerExecution.sumUnitaryFundings);
            position.costPosition += ledgerExecution.settledAmount;
            position.lastExecutedPrice = ledgerExecution.markPrice;
            position.lastSettledPrice = ledgerExecution.markPrice;
            // check balance + settledAmount >= 0, where balance should cast to int128 first
            uint128 balance = account.balances[settlement.settledAssetHash];
            if (balance.toInt128() + ledgerExecution.settledAmount < 0) {
                revert BalanceNotEnough(balance, ledgerExecution.settledAmount);
            }
            account.balances[settlement.settledAssetHash] =
                (balance.toInt128() + ledgerExecution.settledAmount).toUint128();
            if (position.isFullSettled()) {
                delete account.perpPositions[ledgerExecution.symbolHash];
            }
            emit SettlementExecution(
                ledgerExecution.symbolHash,
                ledgerExecution.markPrice,
                ledgerExecution.sumUnitaryFundings,
                ledgerExecution.settledAmount
            );
        }
        if (totalSettleAmount != settlement.settledAmount) revert TotalSettleAmountNotMatch(totalSettleAmount);
        account.lastEngineEventId = eventId;
        // emit event
        emit SettlementResult(
            _newGlobalEventId(),
            settlement.accountId,
            settlement.settledAmount,
            settlement.settledAssetHash,
            settlement.insuranceAccountId,
            settlement.insuranceTransferAmount,
            uint64(length),
            eventId
        );
    }

    function executeLiquidation(EventTypes.Liquidation calldata liquidation, uint64 eventId) external override {
        AccountTypes.Account storage liquidatedAccount = userLedger[liquidation.liquidatedAccountId];

        if (liquidation.insuranceTransferAmount != 0) {
            _transferLiquidatedAssetToInsurance(
                liquidatedAccount,
                liquidation.liquidatedAssetHash,
                liquidation.insuranceTransferAmount,
                liquidation.insuranceAccountId
            );
        }
        uint256 length = liquidation.liquidationTransfers.length;
        for (uint256 i = 0; i < length; i++) {
            EventTypes.LiquidationTransfer calldata liquidationTransfer = liquidation.liquidationTransfers[i];
            _liquidatorLiquidateAndUpdateEventId(
                liquidationTransfer, eventId, liquidationTransfer.liquidatorAccountId != liquidation.insuranceAccountId
            );
            _liquidatedAccountLiquidate(
                liquidatedAccount,
                liquidationTransfer,
                liquidation.liquidatedAccountId != liquidation.insuranceAccountId
            );
            _insuranceLiquidateAndUpdateEventId(liquidation.insuranceAccountId, liquidationTransfer, eventId);
            emit LiquidationTransfer(
                liquidationTransfer.liquidationTransferId,
                liquidationTransfer.liquidatorAccountId,
                liquidationTransfer.symbolHash,
                liquidationTransfer.positionQtyTransfer,
                liquidationTransfer.costPositionTransfer,
                liquidationTransfer.liquidatorFee,
                liquidationTransfer.insuranceFee,
                liquidationTransfer.liquidationFee,
                liquidationTransfer.markPrice,
                liquidationTransfer.sumUnitaryFundings
            );
        }
        liquidatedAccount.lastEngineEventId = eventId;
        // emit event
        emit LiquidationResult(
            _newGlobalEventId(),
            liquidation.liquidatedAccountId,
            liquidation.insuranceAccountId,
            liquidation.liquidatedAssetHash,
            liquidation.insuranceTransferAmount,
            eventId
        );
    }

    function executeAdl(EventTypes.Adl calldata adl, uint64 eventId) external override {
        if (!vaultManager.getAllowedSymbol(adl.symbolHash)) revert SymbolNotAllowed();
        AccountTypes.Account storage account = userLedger[adl.accountId];
        AccountTypes.PerpPosition storage userPosition = account.perpPositions[adl.symbolHash];
        userPosition.chargeFundingFee(adl.sumUnitaryFundings);
        AccountTypes.Account storage insuranceFund = userLedger[adl.insuranceAccountId];
        AccountTypes.PerpPosition storage insurancePosition = insuranceFund.perpPositions[adl.symbolHash];
        int128 tmpUserPositionQty = userPosition.positionQty; // gas saving
        if (tmpUserPositionQty == 0) revert UserPerpPositionQtyZero(adl.accountId, adl.symbolHash);
        if (adl.positionQtyTransfer.abs() > tmpUserPositionQty.abs()) {
            revert InsurancePositionQtyInvalid(adl.positionQtyTransfer, tmpUserPositionQty);
        }

        insurancePosition.chargeFundingFee(adl.sumUnitaryFundings);
        insurancePosition.positionQty -= adl.positionQtyTransfer;
        userPosition.calAverageEntryPrice(adl.positionQtyTransfer, adl.adlPrice.toInt128(), -adl.costPositionTransfer);
        userPosition.positionQty += adl.positionQtyTransfer;
        insurancePosition.costPosition -= adl.costPositionTransfer;
        userPosition.costPosition += adl.costPositionTransfer;

        userPosition.lastExecutedPrice = adl.adlPrice;
        userPosition.lastAdlPrice = adl.adlPrice;

        insurancePosition.lastExecutedPrice = adl.adlPrice;
        insurancePosition.lastAdlPrice = adl.adlPrice;

        account.lastEngineEventId = eventId;
        insuranceFund.lastEngineEventId = eventId;
        emit AdlResult(
            _newGlobalEventId(),
            adl.accountId,
            adl.insuranceAccountId,
            adl.symbolHash,
            adl.positionQtyTransfer,
            adl.costPositionTransfer,
            adl.adlPrice,
            adl.sumUnitaryFundings,
            eventId
        );
    }

    function executeFeeDistribution(EventTypes.FeeDistribution calldata feeDistribution, uint64 eventId)
        external
        override
    {
        AccountTypes.Account storage fromAccount = userLedger[feeDistribution.fromAccountId];
        AccountTypes.Account storage toAccount = userLedger[feeDistribution.toAccountId];
        fromAccount.subBalance(feeDistribution.tokenHash, feeDistribution.amount);
        toAccount.addBalance(feeDistribution.tokenHash, feeDistribution.amount);
        fromAccount.lastEngineEventId = eventId;
        toAccount.lastEngineEventId = eventId;
        // emit event
        emit FeeDistribution(
            _newGlobalEventId(),
            feeDistribution.fromAccountId,
            feeDistribution.toAccountId,
            feeDistribution.amount,
            feeDistribution.tokenHash
        );
    }

    function executeDelegateSigner(EventTypes.DelegateSigner calldata delegateSigner, uint64 eventId)
        external
        override
    {
        // check if cefi has uploaded wrong info
        if (!vaultManager.getAllowedBroker(delegateSigner.brokerHash)) revert BrokerNotAllowed();
        if (delegateSigner.delegateContract == address(0)) revert ZeroDelegateContract();
        if (delegateSigner.delegateSigner == address(0)) revert ZeroDelegateSigner();
        if (delegateSigner.chainId == 0) revert ZeroChainId();

        bytes32 accountId = Utils.calculateAccountId(delegateSigner.delegateContract, delegateSigner.brokerHash);

        // only support one chain delegation
        if (contractSigner[accountId].chainId != 0 && contractSigner[accountId].chainId != delegateSigner.chainId) {
            revert DelegateChainIdNotMatch(accountId, contractSigner[accountId].chainId, delegateSigner.chainId);
        }
        AccountTypes.AccountDelegateSigner memory accountDelegateSigner =
            AccountTypes.AccountDelegateSigner({chainId: delegateSigner.chainId, signer: delegateSigner.delegateSigner});

        contractSigner[accountId] = accountDelegateSigner;
        AccountTypes.Account storage account = userLedger[accountId];
        account.lastEngineEventId = eventId;
        emit DelegateSigner(
            _newGlobalEventId(),
            delegateSigner.chainId,
            accountId,
            delegateSigner.delegateContract,
            delegateSigner.brokerHash,
            delegateSigner.delegateSigner
        );
    }

    function executeDelegateWithdrawAction(EventTypes.WithdrawData calldata withdraw, uint64 eventId)
        external
        override
    {
        // withdraw check
        bytes32 brokerHash = Utils.calculateStringHash(withdraw.brokerId);
        bytes32 tokenHash = Utils.calculateStringHash(withdraw.tokenSymbol);
        if (!vaultManager.getAllowedBroker(brokerHash)) revert BrokerNotAllowed();
        if (!vaultManager.getAllowedChainToken(tokenHash, withdraw.chainId)) {
            revert TokenNotAllowed(tokenHash, withdraw.chainId);
        }
        if (!Utils.validateAccountId(withdraw.accountId, brokerHash, withdraw.sender)) {
            revert AccountIdInvalid();
        }
        AccountTypes.Account storage account = userLedger[withdraw.accountId];
        uint8 state = 0;
        {
            // avoid stack too deep
            AccountTypes.AccountDelegateSigner storage accountDelegateSigner = contractSigner[withdraw.accountId];
            uint128 maxWithdrawFee = vaultManager.getMaxWithdrawFee(tokenHash);
            // https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/326402549/Withdraw+Error+Code
            if (account.lastWithdrawNonce >= withdraw.withdrawNonce) {
                // require withdraw nonce inc
                state = 101;
            } else if (account.balances[tokenHash] < withdraw.tokenAmount) {
                // require balance enough
                state = 1;
            } else if (vaultManager.getBalance(tokenHash, withdraw.chainId) < withdraw.tokenAmount - withdraw.fee) {
                // require chain has enough balance
                state = 2;
            } else if (!Signature.verifyDelegateWithdraw(accountDelegateSigner.signer, withdraw)) {
                // require signature verify
                state = 4;
            } else if (maxWithdrawFee > 0 && maxWithdrawFee < withdraw.fee) {
                // require fee not exceed maxWithdrawFee
                state = 5;
            } else if (withdraw.receiver == address(0)) {
                // require receiver not zero address
                state = 6;
            } else if (accountDelegateSigner.chainId != withdraw.chainId) {
                // require chainId match
                state = 7;
            } else if (withdraw.receiver != withdraw.sender) {
                // require sender = receiver
                state = 8;
            }
        }
        // check all assert, should not change any status

        if (state != 0) {
            emit AccountWithdrawFail(
                withdraw.accountId,
                withdraw.withdrawNonce,
                _newGlobalEventId(),
                brokerHash,
                withdraw.sender,
                withdraw.receiver,
                withdraw.chainId,
                tokenHash,
                withdraw.tokenAmount,
                withdraw.fee,
                state
            );
            return;
        }
        // update status, should never fail
        // frozen balance
        // account should frozen `tokenAmount`, and vault should frozen `tokenAmount - fee`, because vault will payout `tokenAmount - fee`
        account.frozenBalance(withdraw.withdrawNonce, tokenHash, withdraw.tokenAmount);
        vaultManager.frozenBalance(tokenHash, withdraw.chainId, withdraw.tokenAmount - withdraw.fee);
        account.lastEngineEventId = eventId;
        // emit withdraw approve event

        emit AccountWithdrawApprove(
            withdraw.accountId,
            withdraw.withdrawNonce,
            _newGlobalEventId(),
            brokerHash,
            withdraw.sender,
            withdraw.receiver,
            withdraw.chainId,
            tokenHash,
            withdraw.tokenAmount,
            withdraw.fee
        );
        // send cross-chain tx
        ILedgerCrossChainManager(crossChainManagerAddress).withdraw(withdraw);
    }

    function _newGlobalEventId() internal returns (uint64) {
        return ++globalEventId;
    }

    function _newGlobalDepositId() internal returns (uint64) {
        return ++globalDepositId;
    }

    // =================== internal =================== //

    function _feeSwapPosition(
        AccountTypes.PerpPosition storage traderPosition,
        bytes32 symbol,
        int128 feeAmount,
        uint64 tradeId,
        int128 sumUnitaryFundings
    ) internal {
        if (feeAmount == 0) return;
        _perpFeeCollectorDeposit(symbol, feeAmount, tradeId, sumUnitaryFundings);
        traderPosition.costPosition += feeAmount;
    }

    function _perpFeeCollectorDeposit(bytes32 symbol, int128 amount, uint64 tradeId, int128 sumUnitaryFundings)
        internal
    {
        bytes32 feeCollectorAccountId = feeManager.getFeeCollector(IFeeManager.FeeCollectorType.FuturesFeeCollector);
        AccountTypes.Account storage feeCollectorAccount = userLedger[feeCollectorAccountId];
        AccountTypes.PerpPosition storage feeCollectorPosition = feeCollectorAccount.perpPositions[symbol];
        feeCollectorPosition.costPosition -= amount;
        feeCollectorPosition.lastSumUnitaryFundings = sumUnitaryFundings;
        if (tradeId > feeCollectorAccount.lastPerpTradeId) {
            feeCollectorAccount.lastPerpTradeId = tradeId;
        }
    }

    // =================== liquidation functions =================== //

    function _transferLiquidatedAssetToInsurance(
        AccountTypes.Account storage liquidatedAccount,
        bytes32 liquidatedAssetHash,
        uint128 insuranceTransferAmount,
        bytes32 insuranceAccountId
    ) internal {
        liquidatedAccount.subBalance(liquidatedAssetHash, insuranceTransferAmount);
        AccountTypes.Account storage insuranceFund = userLedger[insuranceAccountId];
        insuranceFund.addBalance(liquidatedAssetHash, insuranceTransferAmount);
    }

    function _liquidatorLiquidateAndUpdateEventId(
        EventTypes.LiquidationTransfer calldata liquidationTransfer,
        uint64 eventId,
        bool needCalAvg
    ) internal {
        AccountTypes.Account storage liquidatorAccount = userLedger[liquidationTransfer.liquidatorAccountId];
        AccountTypes.PerpPosition storage liquidatorPosition =
            liquidatorAccount.perpPositions[liquidationTransfer.symbolHash];
        liquidatorPosition.chargeFundingFee(liquidationTransfer.sumUnitaryFundings);
        if (needCalAvg) {
            liquidatorPosition.calAverageEntryPrice(
                liquidationTransfer.positionQtyTransfer,
                liquidationTransfer.markPrice.toInt128(),
                -(liquidationTransfer.costPositionTransfer - liquidationTransfer.liquidatorFee)
            );
        }
        liquidatorPosition.positionQty += liquidationTransfer.positionQtyTransfer;
        liquidatorPosition.costPosition += liquidationTransfer.costPositionTransfer - liquidationTransfer.liquidatorFee;
        liquidatorPosition.lastExecutedPrice = liquidationTransfer.markPrice;
        liquidatorAccount.lastEngineEventId = eventId;
    }

    function _liquidatedAccountLiquidate(
        AccountTypes.Account storage liquidatedAccount,
        EventTypes.LiquidationTransfer calldata liquidationTransfer,
        bool needCalAvg
    ) internal {
        AccountTypes.PerpPosition storage liquidatedPosition =
            liquidatedAccount.perpPositions[liquidationTransfer.symbolHash];
        liquidatedPosition.chargeFundingFee(liquidationTransfer.sumUnitaryFundings);
        if (needCalAvg) {
            liquidatedPosition.calAverageEntryPrice(
                -liquidationTransfer.positionQtyTransfer,
                liquidationTransfer.markPrice.toInt128(),
                liquidationTransfer.costPositionTransfer
                    - (liquidationTransfer.liquidatorFee + liquidationTransfer.insuranceFee)
            );
        }
        liquidatedPosition.positionQty -= liquidationTransfer.positionQtyTransfer;

        liquidatedPosition.costPosition += liquidationTransfer.liquidationFee - liquidationTransfer.costPositionTransfer;
        liquidatedPosition.lastExecutedPrice = liquidationTransfer.markPrice;
        if (liquidatedPosition.isFullSettled()) {
            delete liquidatedAccount.perpPositions[liquidationTransfer.symbolHash];
        }
    }

    function _insuranceLiquidateAndUpdateEventId(
        bytes32 insuranceAccountId,
        EventTypes.LiquidationTransfer calldata liquidationTransfer,
        uint64 eventId
    ) internal {
        AccountTypes.Account storage insuranceFund = userLedger[insuranceAccountId];
        AccountTypes.PerpPosition storage insurancePosition =
            insuranceFund.perpPositions[liquidationTransfer.symbolHash];
        insurancePosition.chargeFundingFee(liquidationTransfer.sumUnitaryFundings);
        insurancePosition.costPosition -= liquidationTransfer.insuranceFee;
        insurancePosition.lastExecutedPrice = liquidationTransfer.markPrice;
        insuranceFund.lastEngineEventId = eventId;
    }
}

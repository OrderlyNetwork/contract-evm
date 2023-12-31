// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "./dataLayout/LedgerDataLayout.sol";
import "./interface/ILedger.sol";
import "./interface/IVaultManager.sol";
import "./interface/ILedgerCrossChainManager.sol";
import "./interface/IMarketManager.sol";
import "./interface/IFeeManager.sol";
import "./library/Utils.sol";
import "./library/Signature.sol";
import "./library/typesHelper/AccountTypeHelper.sol";
import "./library/typesHelper/AccountTypePositionHelper.sol";
import "./library/typesHelper/SafeCastHelper.sol";

/// @title Ledger contract
/// @author Orderly_Rubick
/// @notice Ledger is responsible for saving traders' Account (balance, perpPosition, and other meta)
/// and global state (e.g. futuresUploadBatchId)
/// This contract should only have one in main-chain (e.g. OP orderly L2)
contract Ledger is ILedger, OwnableUpgradeable, LedgerDataLayout {
    using AccountTypeHelper for AccountTypes.Account;
    using AccountTypePositionHelper for AccountTypes.PerpPosition;
    using SafeCastHelper for *;

    // TODO ledgerImpl1, LedgerImpl2 addresses start here
    // usage: `ledgerImpl1.delegatecall(abi.encodeWithSelector(ILedger.accountDeposit.selector, data));`

    /// @notice require operator
    modifier onlyOperatorManager() {
        if (msg.sender != operatorManagerAddress) revert OnlyOperatorCanCall();
        _;
    }

    /// @notice require crossChainManager
    modifier onlyCrossChainManager() {
        if (msg.sender != crossChainManagerAddress) revert OnlyCrossChainManagerCanCall();
        _;
    }

    /// @notice check non-zero address
    modifier nonZeroAddress(address _address) {
        if (_address == address(0)) revert AddressZero();
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize() external override initializer {
        __Ownable_init();
    }

    /// @notice Set the address of operatorManager contract
    /// @param _operatorManagerAddress new operatorManagerAddress
    function setOperatorManagerAddress(address _operatorManagerAddress)
        public
        override
        onlyOwner
        nonZeroAddress(_operatorManagerAddress)
    {
        emit ChangeOperatorManager(operatorManagerAddress, _operatorManagerAddress);
        operatorManagerAddress = _operatorManagerAddress;
    }

    /// @notice Set the address of crossChainManager on Ledger side
    /// @param _crossChainManagerAddress  new crossChainManagerAddress
    function setCrossChainManager(address _crossChainManagerAddress)
        public
        override
        onlyOwner
        nonZeroAddress(_crossChainManagerAddress)
    {
        emit ChangeCrossChainManager(crossChainManagerAddress, _crossChainManagerAddress);
        crossChainManagerAddress = _crossChainManagerAddress;
    }

    /// @notice Set the address of vaultManager contract
    /// @param _vaultManagerAddress new vaultManagerAddress
    function setVaultManager(address _vaultManagerAddress)
        public
        override
        onlyOwner
        nonZeroAddress(_vaultManagerAddress)
    {
        emit ChangeVaultManager(address(vaultManager), _vaultManagerAddress);
        vaultManager = IVaultManager(_vaultManagerAddress);
    }

    /// @notice Set the address of marketManager contract
    /// @param _marketManagerAddress new marketManagerAddress
    function setMarketManager(address _marketManagerAddress)
        public
        override
        onlyOwner
        nonZeroAddress(_marketManagerAddress)
    {
        emit ChangeMarketManager(address(marketManager), _marketManagerAddress);
        marketManager = IMarketManager(_marketManagerAddress);
    }

    /// @notice Set the address of feeManager contract
    /// @param _feeManagerAddress new feeManagerAddress
    function setFeeManager(address _feeManagerAddress) public override onlyOwner nonZeroAddress(_feeManagerAddress) {
        emit ChangeFeeManager(address(feeManager), _feeManagerAddress);
        feeManager = IFeeManager(_feeManagerAddress);
    }

    /// @notice Get the amount of a token frozen balance for a given account and the corresponding withdrawNonce
    /// @param accountId accountId to query
    /// @param withdrawNonce withdrawNonce to query
    /// @param tokenHash tokenHash to query
    /// @return uint128 frozen value
    function getFrozenWithdrawNonce(bytes32 accountId, uint64 withdrawNonce, bytes32 tokenHash)
        public
        view
        override
        returns (uint128)
    {
        return userLedger[accountId].getFrozenWithdrawNonceBalance(withdrawNonce, tokenHash);
    }

    /// @notice omni batch get
    /// @param accountIds accountId list to query
    /// @param tokens token list to query
    /// @param symbols symbol list to query
    /// @return accountSnapshots account snapshot list for the given tokens and symbols
    function batchGetUserLedger(bytes32[] calldata accountIds, bytes32[] memory tokens, bytes32[] memory symbols)
        public
        view
        override
        returns (AccountTypes.AccountSnapshot[] memory accountSnapshots)
    {
        uint256 accountIdLength = accountIds.length;
        uint256 tokenLength = tokens.length;
        uint256 symbolLength = symbols.length;
        accountSnapshots = new AccountTypes.AccountSnapshot[](accountIdLength);
        for (uint256 i = 0; i < accountIdLength; ++i) {
            bytes32 accountId = accountIds[i];
            AccountTypes.Account storage account = userLedger[accountId];
            AccountTypes.AccountTokenBalances[] memory tokenInner = new AccountTypes.AccountTokenBalances[](tokenLength);
            for (uint256 j = 0; j < tokenLength; ++j) {
                bytes32 tokenHash = tokens[j];
                tokenInner[j] = AccountTypes.AccountTokenBalances({
                    tokenHash: tokenHash,
                    balance: account.getBalance(tokenHash),
                    frozenBalance: account.getFrozenTotalBalance(tokenHash)
                });
            }
            AccountTypes.AccountPerpPositions[] memory symbolInner =
                new AccountTypes.AccountPerpPositions[](symbolLength);
            for (uint256 j = 0; j < symbolLength; ++j) {
                bytes32 symbolHash = symbols[j];
                AccountTypes.PerpPosition storage perpPosition = account.perpPositions[symbolHash];
                symbolInner[j] = AccountTypes.AccountPerpPositions({
                    symbolHash: symbolHash,
                    positionQty: perpPosition.positionQty,
                    costPosition: perpPosition.costPosition,
                    lastSumUnitaryFundings: perpPosition.lastSumUnitaryFundings,
                    lastExecutedPrice: perpPosition.lastExecutedPrice,
                    lastSettledPrice: perpPosition.lastSettledPrice,
                    averageEntryPrice: perpPosition.averageEntryPrice,
                    openingCost: perpPosition.openingCost,
                    lastAdlPrice: perpPosition.lastAdlPrice
                });
            }
            accountSnapshots[i] = AccountTypes.AccountSnapshot({
                accountId: accountId,
                brokerHash: account.brokerHash,
                userAddress: account.userAddress,
                lastWithdrawNonce: account.lastWithdrawNonce,
                lastPerpTradeId: account.lastPerpTradeId,
                lastEngineEventId: account.lastEngineEventId,
                lastDepositEventId: account.lastDepositEventId,
                tokenBalances: tokenInner,
                perpPositions: symbolInner
            });
        }
    }

    function batchGetUserLedger(bytes32[] calldata accountIds)
        public
        view
        returns (AccountTypes.AccountSnapshot[] memory)
    {
        bytes32[] memory tokens = vaultManager.getAllAllowedToken();
        bytes32[] memory symbols = vaultManager.getAllAllowedSymbol();
        return batchGetUserLedger(accountIds, tokens, symbols);
    }

    /// Interface implementation

    /// @notice The cross chain manager will call this function to notify the deposit event to the Ledger contract
    /// @param data account deposit data
    function accountDeposit(AccountTypes.AccountDeposit calldata data) external override onlyCrossChainManager {
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

    function executeProcessValidatedFutures(PerpTypes.FuturesTradeUpload calldata trade)
        external
        override
        onlyOperatorManager
    {
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

    function executeWithdrawAction(EventTypes.WithdrawData calldata withdraw, uint64 eventId)
        external
        override
        onlyOperatorManager
    {
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

    function accountWithDrawFinish(AccountTypes.AccountWithdraw calldata withdraw)
        external
        override
        onlyCrossChainManager
    {
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

    function executeSettlement(EventTypes.Settlement calldata settlement, uint64 eventId)
        external
        override
        onlyOperatorManager
    {
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

    function executeLiquidation(EventTypes.Liquidation calldata liquidation, uint64 eventId)
        external
        override
        onlyOperatorManager
    {
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

    function executeAdl(EventTypes.Adl calldata adl, uint64 eventId) external override onlyOperatorManager {
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

    function executeRebalanceBurn(RebalanceTypes.RebalanceBurnUploadData calldata data)
        external
        override
        onlyOperatorManager
    {
        (uint32 dstDomain, address dstVaultAddress) = vaultManager.executeRebalanceBurn(data);
        // send cc message with:
        // rebalanceId, amount, tokenHash, burnChainId, mintChainId | dstDomain, dstVaultAddress
        ILedgerCrossChainManager(crossChainManagerAddress).burn(
            RebalanceTypes.RebalanceBurnCCData({
                dstDomain: dstDomain,
                rebalanceId: data.rebalanceId,
                amount: data.amount,
                tokenHash: data.tokenHash,
                burnChainId: data.burnChainId,
                mintChainId: data.mintChainId,
                dstVaultAddress: dstVaultAddress
            })
        );
    }

    function rebalanceBurnFinish(RebalanceTypes.RebalanceBurnCCFinishData calldata data)
        external
        override
        onlyCrossChainManager
    {
        vaultManager.rebalanceBurnFinish(data);
    }

    function executeRebalanceMint(RebalanceTypes.RebalanceMintUploadData calldata data)
        external
        override
        onlyOperatorManager
    {
        vaultManager.executeRebalanceMint(data);
        // send cc Message with:
        // rebalanceId, amount, tokenHash, burnChainId, mintChainId | messageBytes, messageSignature
        ILedgerCrossChainManager(crossChainManagerAddress).mint(
            RebalanceTypes.RebalanceMintCCData({
                rebalanceId: data.rebalanceId,
                amount: data.amount,
                tokenHash: data.tokenHash,
                burnChainId: data.burnChainId,
                mintChainId: data.mintChainId,
                messageBytes: data.messageBytes,
                messageSignature: data.messageSignature
            })
        );
    }

    function rebalanceMintFinish(RebalanceTypes.RebalanceMintCCFinishData calldata data)
        external
        override
        onlyCrossChainManager
    {
        vaultManager.rebalanceMintFinish(data);
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
        uint128 feeAmount,
        uint64 tradeId,
        int128 sumUnitaryFundings
    ) internal {
        if (feeAmount == 0) return;
        _perpFeeCollectorDeposit(symbol, feeAmount, tradeId, sumUnitaryFundings);
        traderPosition.costPosition += feeAmount.toInt128();
    }

    function _perpFeeCollectorDeposit(bytes32 symbol, uint128 amount, uint64 tradeId, int128 sumUnitaryFundings)
        internal
    {
        bytes32 feeCollectorAccountId = feeManager.getFeeCollector(IFeeManager.FeeCollectorType.FuturesFeeCollector);
        AccountTypes.Account storage feeCollectorAccount = userLedger[feeCollectorAccountId];
        AccountTypes.PerpPosition storage feeCollectorPosition = feeCollectorAccount.perpPositions[symbol];
        feeCollectorPosition.costPosition -= amount.toInt128();
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

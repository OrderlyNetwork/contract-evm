// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
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

/**
 * Ledger is responsible for saving traders' Account (balance, perpPosition, and other meta)
 * and global state (e.g. futuresUploadBatchId)
 * This contract should only have one in main-chain (avalanche)
 */
contract Ledger is ILedger, OwnableUpgradeable {
    using AccountTypeHelper for AccountTypes.Account;
    using AccountTypePositionHelper for AccountTypes.PerpPosition;
    using SafeCastHelper for *;

    // OperatorManager contract address
    address public operatorManagerAddress;
    // crossChainManagerAddress contract address
    address public crossChainManagerAddress;
    // TODO @Rubick reorder to save slots
    // operatorTradesBatchId
    uint64 public operatorTradesBatchId;
    // globalEventId, for event trade upload
    uint64 public globalEventId;
    // globalDepositId
    uint64 public globalDepositId;
    // @Rubick refactor order when next deployment
    // userLedger accountId -> Account
    mapping(bytes32 => AccountTypes.Account) internal userLedger;

    // VaultManager contract
    IVaultManager public vaultManager;
    // @Rubick remove this when next deployment
    // CrossChainManager contract
    ILedgerCrossChainManager public _deprecated;
    // MarketManager contract
    IMarketManager public marketManager;
    // FeeManager contract
    IFeeManager public feeManager;

    // require operator
    modifier onlyOperatorManager() {
        if (msg.sender != operatorManagerAddress) revert OnlyOperatorCanCall();
        _;
    }

    // require crossChainManager
    modifier onlyCrossChainManager() {
        if (msg.sender != crossChainManagerAddress) revert OnlyCrossChainManagerCanCall();
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize() public override initializer {
        __Ownable_init();
    }

    // set operatorManagerAddress
    function setOperatorManagerAddress(address _operatorManagerAddress) public override onlyOwner {
        operatorManagerAddress = _operatorManagerAddress;
    }

    // set crossChainManager & Address
    function setCrossChainManager(address _crossChainManagerAddress) public override onlyOwner {
        crossChainManagerAddress = _crossChainManagerAddress;
    }

    // set vaultManager
    function setVaultManager(address _vaultManagerAddress) public override onlyOwner {
        vaultManager = IVaultManager(_vaultManagerAddress);
    }

    // set marketManager
    function setMarketManager(address _marketManagerAddress) public override onlyOwner {
        marketManager = IMarketManager(_marketManagerAddress);
    }

    // set feeManager
    function setFeeManager(address _feeManagerAddress) public override onlyOwner {
        feeManager = IFeeManager(_feeManagerAddress);
    }

    // get frozen withdrawNonce balance
    function getFrozenWithdrawNonce(bytes32 accountId, uint64 withdrawNonce, bytes32 tokenHash)
        public
        view
        override
        returns (uint128)
    {
        return userLedger[accountId].getFrozenWithdrawNonceBalance(withdrawNonce, tokenHash);
    }

    // omni batch get
    function batchGetUserLedgerByTokens(
        bytes32[] calldata accountIds,
        bytes32[] memory tokens,
        bytes32[] memory symbols
    ) public view override returns (AccountTypes.AccountSnapshot[] memory accountFlats) {
        uint256 accountIdLength = accountIds.length;
        uint256 tokenLength = tokens.length;
        uint256 symbolLength = symbols.length;
        accountFlats = new AccountTypes.AccountSnapshot[](accountIdLength);
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
            accountFlats[i] = AccountTypes.AccountSnapshot({
                accountId: accountId,
                brokerHash: account.brokerHash,
                userAddress: account.userAddress,
                lastWithdrawNonce: account.lastWithdrawNonce,
                lastPerpTradeId: account.lastPerpTradeId,
                lastCefiEventId: account.lastCefiEventId,
                lastDepositEventId: account.lastDepositEventId,
                tokenBalances: tokenInner,
                perpPositions: symbolInner
            });
        }
    }

    function batchGetUserLedger(bytes32[] calldata accountIds)
        external
        view
        returns (AccountTypes.AccountSnapshot[] memory)
    {
        bytes32[] memory tokens = vaultManager.getAllAllowedToken();
        bytes32[] memory symbols = vaultManager.getAllAllowedSymbol();
        return batchGetUserLedgerByTokens(accountIds, tokens, symbols);
    }

    // Interface implementation

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
            emit AccountRegister(data.accountId, data.brokerHash, data.userAddress, block.timestamp);
        }
        account.addBalance(data.tokenHash, data.tokenAmount);
        vaultManager.addBalance(data.tokenHash, data.srcChainId, data.tokenAmount);
        uint64 tmpGlobalDepositId = _newGlobalDepositId(); // gas saving
        account.lastDepositEventId = tmpGlobalDepositId;
        // emit deposit event
        emit AccountDeposit(
            data.accountId,
            tmpGlobalDepositId,
            _newGlobalEventId(),
            data.userAddress,
            data.tokenHash,
            data.tokenAmount,
            data.srcChainId,
            data.srcChainDepositNonce,
            data.brokerHash,
            block.timestamp
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
    }

    function executeWithdrawAction(EventTypes.WithdrawData calldata withdraw, uint64 eventId)
        external
        override
        onlyOperatorManager
    {
        bytes32 brokerHash = Utils.getBrokerHash(withdraw.brokerId);
        bytes32 tokenHash = Utils.getTokenHash(withdraw.tokenSymbol);
        if (!vaultManager.getAllowedBroker(brokerHash)) revert BrokerNotAllowed();
        if (!vaultManager.getAllowedChainToken(tokenHash, withdraw.chainId)) {
            revert TokenNotAllowed(tokenHash, withdraw.chainId);
        }
        if (!Utils.validateAccountId(withdraw.accountId, brokerHash, withdraw.sender)) revert AccountIdInvalid();
        AccountTypes.Account storage account = userLedger[withdraw.accountId];
        uint8 state = 0;
        // https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/326402549/Withdraw+Error+Code
        if (account.lastWithdrawNonce >= withdraw.withdrawNonce) {
            // require withdraw nonce inc
            state = 101;
        } else if (account.balances[tokenHash] < withdraw.tokenAmount) {
            // require balance enough
            state = 1;
        } else if (vaultManager.getBalance(tokenHash, withdraw.chainId) < withdraw.tokenAmount) {
            // require chain has enough balance
            state = 2;
        } else if (!Signature.verifyWithdraw(withdraw.sender, withdraw)) {
            // require signature verify
            state = 4;
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
                block.timestamp,
                state
            );
            return;
        }
        // update status, should never fail
        // frozen balance
        account.frozenBalance(withdraw.withdrawNonce, tokenHash, withdraw.tokenAmount);
        account.lastWithdrawNonce = withdraw.withdrawNonce;
        vaultManager.subBalance(tokenHash, withdraw.chainId, withdraw.tokenAmount);
        account.lastCefiEventId = eventId;
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
            withdraw.fee,
            block.timestamp
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
        // withdraw fee
        if (withdraw.fee > 0) {
            // gas saving if no fee
            bytes32 feeCollectorAccountId =
                feeManager.getFeeCollector(IFeeManager.FeeCollectorType.OperatorGasFeeCollector);
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
            withdraw.fee,
            block.timestamp
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
        for (uint256 i = 0; i < length; ++i) {
            totalSettleAmount += settlementExecutions[i].settledAmount;
        }
        if (totalSettleAmount != settlement.settledAmount) revert TotalSettleAmountNotMatch(totalSettleAmount);

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
            insuranceFund.balances[settlement.settledAssetHash] += settlement.insuranceTransferAmount;
            account.balances[settlement.settledAssetHash] += settlement.insuranceTransferAmount;
        }
        // for-loop ledger execution
        for (uint256 i = 0; i < length; ++i) {
            EventTypes.SettlementExecution calldata ledgerExecution = settlementExecutions[i];
            AccountTypes.PerpPosition storage position = account.perpPositions[ledgerExecution.symbolHash];
            if (position.positionQty != 0) {
                position.chargeFundingFee(ledgerExecution.sumUnitaryFundings);
                position.costPosition += ledgerExecution.settledAmount;
                position.lastExecutedPrice = ledgerExecution.markPrice;
            }
            // check balance + settledAmount >= 0, where balance should cast to int128 first
            uint128 balance = account.balances[settlement.settledAssetHash];
            if (balance.toInt128() + ledgerExecution.settledAmount < 0) {
                revert BalanceNotEnough(balance, ledgerExecution.settledAmount);
            }
            account.balances[settlement.settledAssetHash] =
                (balance.toInt128() + ledgerExecution.settledAmount).toUint128();
        }
        account.lastCefiEventId = eventId;
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
            _liquidatorLiquidateAndUpdateEventId(liquidation.liquidationTransfers[i], eventId);
            _liquidatedAccountLiquidate(liquidatedAccount, liquidation.liquidationTransfers[i]);
            _insuranceLiquidateAndUpdateEventId(
                liquidation.insuranceAccountId, liquidation.liquidationTransfers[i], eventId
            );
        }
        liquidatedAccount.lastCefiEventId = eventId;
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

        account.lastCefiEventId = eventId;
        insuranceFund.lastCefiEventId = eventId;
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
        uint64 eventId
    ) internal {
        AccountTypes.Account storage liquidatorAccount = userLedger[liquidationTransfer.liquidatorAccountId];
        AccountTypes.PerpPosition storage liquidatorPosition =
            liquidatorAccount.perpPositions[liquidationTransfer.symbolHash];
        liquidatorPosition.chargeFundingFee(liquidationTransfer.sumUnitaryFundings);
        liquidatorPosition.calAverageEntryPrice(
            liquidationTransfer.positionQtyTransfer,
            liquidationTransfer.markPrice.toInt128(),
            -(liquidationTransfer.costPositionTransfer - liquidationTransfer.liquidatorFee)
        );
        liquidatorPosition.positionQty += liquidationTransfer.positionQtyTransfer;
        liquidatorPosition.costPosition += liquidationTransfer.costPositionTransfer - liquidationTransfer.liquidatorFee;
        liquidatorPosition.lastExecutedPrice = liquidationTransfer.markPrice;
        liquidatorAccount.lastCefiEventId = eventId;
    }

    function _liquidatedAccountLiquidate(
        AccountTypes.Account storage liquidatedAccount,
        EventTypes.LiquidationTransfer calldata liquidationTransfer
    ) internal {
        AccountTypes.PerpPosition storage liquidatedPosition =
            liquidatedAccount.perpPositions[liquidationTransfer.symbolHash];
        liquidatedPosition.chargeFundingFee(liquidationTransfer.sumUnitaryFundings);
        liquidatedPosition.calAverageEntryPrice(
            -liquidationTransfer.positionQtyTransfer,
            liquidationTransfer.markPrice.toInt128(),
            liquidationTransfer.costPositionTransfer
                - (liquidationTransfer.liquidatorFee + liquidationTransfer.insuranceFee)
        );
        liquidatedPosition.positionQty -= liquidationTransfer.positionQtyTransfer;
        // liquidatedPosition.costPosition = liquidatedPosition.costPosition - liquidationTransfer.costPositionTransfer
        //     + liquidationTransfer.liquidationFee;
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
        insuranceFund.lastCefiEventId = eventId;
    }

    // every time call `upgradeAndCall` will call this function, to do some data migrate or value init
    function upgradeInit() external {}
}

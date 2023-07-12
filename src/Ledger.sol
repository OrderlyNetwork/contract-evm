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

/**
 * Ledger is responsible for saving traders' Account (balance, perpPosition, and other meta)
 * and global state (e.g. futuresUploadBatchId)
 * This contract should only have one in main-chain (avalanche)
 */
contract Ledger is ILedger, OwnableUpgradeable {
    using AccountTypeHelper for AccountTypes.Account;
    using AccountTypePositionHelper for AccountTypes.PerpPosition;

    // OperatorManager contract address
    address public operatorManagerAddress;
    // crossChainManagerAddress contract address
    address public crossChainManagerAddress;
    // operatorTradesBatchId
    uint64 public operatorTradesBatchId;
    // globalEventId, for deposit and withdraw
    uint64 public globalEventId;
    // globalDepositId
    uint64 public globalDepositId;
    // userLedger accountId -> Account
    mapping(bytes32 => AccountTypes.Account) internal userLedger;

    // VaultManager contract
    IVaultManager public vaultManager;
    // CrossChainManager contract
    ILedgerCrossChainManager public crossChainManager;
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
        crossChainManager = ILedgerCrossChainManager(_crossChainManagerAddress);
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

    // get userLedger balance
    function getUserLedgerBalance(bytes32 accountId, bytes32 tokenHash) public view override returns (uint128) {
        return userLedger[accountId].getBalance(tokenHash);
    }

    // get userLedger brokerId
    function getUserLedgerBrokerHash(bytes32 accountId) public view override returns (bytes32) {
        return userLedger[accountId].getBrokerHash();
    }

    // get userLedger lastCefiEventId
    function getUserLedgerLastCefiEventId(bytes32 accountId) public view override returns (uint64) {
        return userLedger[accountId].getLastCefiEventId();
    }

    // get frozen total balance
    function getFrozenTotalBalance(bytes32 accountId, bytes32 tokenHash) public view override returns (uint128) {
        return userLedger[accountId].getFrozenTotalBalance(tokenHash);
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

    // get perp position
    function getPerpPosition(bytes32 accountId, bytes32 symbolHash)
        public
        view
        override
        returns (AccountTypes.PerpPosition memory perpPosition)
    {
        perpPosition = userLedger[accountId].perpPositions[symbolHash];
    }

    // Interface implementation

    function accountDeposit(AccountTypes.AccountDeposit calldata data) public override onlyCrossChainManager {
        // validate data first
        if (!vaultManager.getAllowedBroker(data.brokerHash)) revert BrokerNotAllowed();
        if (!vaultManager.getAllowedToken(data.tokenHash, data.srcChainId)) {
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
        account.lastDepositEventId = _newGlobalDepositId();
        // emit deposit event
        emit AccountDeposit(
            data.accountId,
            globalDepositId,
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
        public
        override
        onlyOperatorManager
    {
        AccountTypes.Account storage account = userLedger[trade.accountId];
        AccountTypes.PerpPosition storage perpPosition = account.perpPositions[trade.symbolHash];
        perpPosition.chargeFundingFee(trade.sumUnitaryFundings);
        perpPosition.calAverageEntryPrice(trade.tradeQty, int128(trade.executedPrice), 0);
        perpPosition.positionQty += trade.tradeQty;
        perpPosition.costPosition += trade.notional;
        perpPosition.lastExecutedPrice = trade.executedPrice;
        // fee_swap_position
        feeSwapPosition(perpPosition, trade.symbolHash, trade.fee, trade.tradeId, trade.sumUnitaryFundings);
        account.lastPerpTradeId = trade.tradeId;
        // update last funding update timestamp
        marketManager.setLastFundingUpdated(trade.symbolHash, trade.timestamp);
    }

    function executeWithdrawAction(EventTypes.WithdrawData calldata withdraw, uint64 eventId)
        public
        override
        onlyOperatorManager
    {
        bytes32 brokerHash = Utils.getBrokerHash(withdraw.brokerId);
        bytes32 tokenHash = Utils.getTokenHash(withdraw.tokenSymbol);
        if (!vaultManager.getAllowedBroker(brokerHash)) revert BrokerNotAllowed();
        if (!vaultManager.getAllowedToken(tokenHash, withdraw.chainId)) {
            revert TokenNotAllowed(tokenHash, withdraw.chainId);
        }
        if (!Utils.validateAccountId(withdraw.accountId, brokerHash, withdraw.sender)) revert AccountIdInvalid();
        AccountTypes.Account storage account = userLedger[withdraw.accountId];
        uint8 state = 0;
        if (account.balances[tokenHash] < withdraw.tokenAmount) {
            // require balance enough
            state = 1;
        } else if (vaultManager.getBalance(tokenHash, withdraw.chainId) < withdraw.tokenAmount) {
            // require chain has enough balance
            state = 2;
        } else if (account.lastWithdrawNonce >= withdraw.withdrawNonce) {
            // require withdraw nonce inc
            state = 3;
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
                account.brokerHash,
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
            account.brokerHash,
            withdraw.sender,
            withdraw.receiver,
            withdraw.chainId,
            tokenHash,
            withdraw.tokenAmount,
            withdraw.fee,
            block.timestamp
        );
        // send cross-chain tx
        crossChainManager.withdraw(withdraw);
    }

    function accountWithDrawFinish(AccountTypes.AccountWithdraw calldata withdraw)
        public
        override
        onlyCrossChainManager
    {
        AccountTypes.Account storage account = userLedger[withdraw.accountId];
        // finish frozen balance
        account.finishFrozenBalance(withdraw.withdrawNonce, withdraw.tokenHash, withdraw.tokenAmount);
        // withdraw fee
        if (withdraw.fee > 0) {
            // gas saving if no fee
            feeManager.setOperatorGasFeeBalance(
                withdraw.tokenHash, feeManager.getOperatorGasFeeBalance(withdraw.tokenHash) + withdraw.fee
            );
        }
        // emit withdraw finish event
        emit AccountWithdrawFinish(
            withdraw.accountId,
            withdraw.withdrawNonce,
            _newGlobalEventId(),
            account.brokerHash,
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
        public
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
                int128(balance) + int128(settlement.insuranceTransferAmount) + settlement.settledAmount < 0
                    || settlement.insuranceTransferAmount > uint128(Utils.abs(settlement.settledAmount))
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
            if (int128(account.balances[settlement.settledAssetHash]) + ledgerExecution.settledAmount < 0) {
                revert BalanceNotEnough(balance, ledgerExecution.settledAmount);
            }
            account.balances[settlement.settledAssetHash] =
                uint128(int128(account.balances[settlement.settledAssetHash]) + ledgerExecution.settledAmount);
        }
        account.lastCefiEventId = eventId;
        // emit event
        emit SettlementResult(
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
        public
        override
        onlyOperatorManager
    {}

    function executeAdl(EventTypes.Adl calldata adl, uint64 eventId) public override onlyOperatorManager {
        AccountTypes.Account storage account = userLedger[adl.accountId];
        AccountTypes.PerpPosition storage userPosition = account.perpPositions[adl.symbolHash];
        userPosition.chargeFundingFee(adl.sumUnitaryFundings);
        AccountTypes.Account storage insuranceFund = userLedger[adl.insuranceAccountId];
        AccountTypes.PerpPosition storage insurancePosition = insuranceFund.perpPositions[adl.symbolHash];
        if (userPosition.positionQty == 0) revert UserPerpPositionQtyZero(adl.accountId, adl.symbolHash);
        if (Utils.abs(adl.positionQtyTransfer) > Utils.abs(userPosition.positionQty)) {
            revert InsurancePositionQtyInvalid(adl.positionQtyTransfer, userPosition.positionQty);
        }

        insurancePosition.chargeFundingFee(adl.sumUnitaryFundings);
        insurancePosition.positionQty -= adl.positionQtyTransfer;
        userPosition.calAverageEntryPrice(adl.positionQtyTransfer, int128(adl.adlPrice), -adl.costPositionTransfer);
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

    function executePerpMarketInfo(MarketTypes.PerpMarketUpload calldata data) public override onlyOperatorManager {
        // TODO change me
        if (data.bizType == 0) {
            MarketTypes.PerpPriceInner memory innerData = abi.decode(data.data, (MarketTypes.PerpPriceInner));
            marketManager.updatePerpPrices(innerData);
        } else if (data.bizType == 1) {
            MarketTypes.SumUnitaryFundingsInner memory innerData =
                abi.decode(data.data, (MarketTypes.SumUnitaryFundingsInner));
            marketManager.updateSumUnitaryFundings(innerData);
        }
    }

    function _newGlobalEventId() internal returns (uint64) {
        globalEventId += 1;
        return globalEventId;
    }

    function _newGlobalDepositId() internal returns (uint64) {
        globalDepositId += 1;
        return globalDepositId;
    }

    // =================== internal =================== //

    function feeSwapPosition(
        AccountTypes.PerpPosition storage traderPosition,
        bytes32 symbol,
        uint128 feeAmount,
        uint64 tradeId,
        int128 sumUnitaryFundings
    ) internal {
        if (feeAmount == 0) return;
        perpFeeCollectorDeposit(symbol, feeAmount, tradeId, sumUnitaryFundings);
        traderPosition.costPosition += int128(feeAmount);
    }

    function perpFeeCollectorDeposit(bytes32 symbol, uint128 amount, uint64 tradeId, int128 sumUnitaryFundings)
        internal
    {
        bytes32 feeCollectorAccountId = feeManager.getFeeCollector(IFeeManager.FeeCollectorType.FuturesFeeCollector);
        AccountTypes.Account storage feeCollectorAccount = userLedger[feeCollectorAccountId];
        AccountTypes.PerpPosition storage feeCollectorPosition = feeCollectorAccount.perpPositions[symbol];
        feeCollectorPosition.costPosition -= int128(amount);
        feeCollectorPosition.lastSumUnitaryFundings = sumUnitaryFundings;
        if (tradeId > feeCollectorAccount.lastPerpTradeId) {
            feeCollectorAccount.lastPerpTradeId = tradeId;
        }
    }
}

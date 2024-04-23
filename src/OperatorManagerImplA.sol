// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "./dataLayout/OperatorManagerDataLayout.sol";
import "./interface/ILedger.sol";
import "./interface/IMarketManager.sol";
import "./interface/IOperatorManagerImplA.sol";
import "./library/Signature.sol";

/// @title OperatorManager contract, implementation part A contract, for resolve EIP170 limit
/// @author Orderly_Rubick
contract OperatorManagerImplA is IOperatorManagerImplA, OwnableUpgradeable, OperatorManagerDataLayout {
    constructor() {
        _disableInitializers();
    }

    function initialize() external override initializer {
        __Ownable_init();
    }

    /// @notice Operator ping to update last operator interaction timestamp
    function operatorPing() external override {
        _innerPing();
    }

    /// @notice Function for perpetual futures trade upload
    function futuresTradeUpload(PerpTypes.FuturesTradeUploadData calldata data) external override {
        if (data.batchId != futuresUploadBatchId) revert BatchIdNotMatch(data.batchId, futuresUploadBatchId);
        _innerPing();
        _futuresTradeUploadData(data);
        // emit event
        emit FuturesTradeUpload(data.batchId);
        // next wanted futuresUploadBatchId
        futuresUploadBatchId += 1;
    }

    /// @notice Function for event upload
    function eventUpload(EventTypes.EventUpload calldata data) external override {
        if (data.batchId != eventUploadBatchId) revert BatchIdNotMatch(data.batchId, eventUploadBatchId);
        _innerPing();
        _eventUploadData(data);
        // emit event
        emit EventUpload(data.batchId);
        // next wanted eventUploadBatchId
        eventUploadBatchId += 1;
    }

    /// @notice Function for perpetual futures price upload
    function perpPriceUpload(MarketTypes.UploadPerpPrice calldata data) external override {
        _innerPing();
        _perpMarketInfo(data);
    }

    /// @notice Function for sum unitary fundings upload
    function sumUnitaryFundingsUpload(MarketTypes.UploadSumUnitaryFundings calldata data) external override {
        _innerPing();
        _perpMarketInfo(data);
    }

    // @notice Function for rebalance burn upload
    function rebalanceBurnUpload(RebalanceTypes.RebalanceBurnUploadData calldata data) external override {
        _innerPing();
        _rebalanceBurnUpload(data);
        // emit event
        emit RebalanceBurnUpload(data.rebalanceId);
    }

    // @notice Function for rebalance mint upload
    function rebalanceMintUpload(RebalanceTypes.RebalanceMintUploadData calldata data) external override {
        _innerPing();
        _rebalanceMintUpload(data);
        // emit event
        emit RebalanceMintUpload(data.rebalanceId);
    }

    /// @notice Function to verify Engine signature for futures trade upload data, if validated then Ledger contract will be called to execute the trade process
    function _futuresTradeUploadData(PerpTypes.FuturesTradeUploadData calldata data) internal {
        PerpTypes.FuturesTradeUpload[] calldata trades = data.trades;
        if (trades.length != data.count) revert CountNotMatch(trades.length, data.count);

        // check engine signature
        bool succ = Signature.perpUploadEncodeHashVerify(data, enginePerpTradeUploadAddress);
        if (!succ) revert SignatureNotMatch();

        // process each validated perp trades
        for (uint256 i = 0; i < data.count; i++) {
            _processValidatedFutures(trades[i]);
        }
    }

    /// @notice Cross-Contract call to Ledger contract to process each validated perp future trades
    function _processValidatedFutures(PerpTypes.FuturesTradeUpload calldata trade) internal {
        ledger.executeProcessValidatedFutures(trade);
    }

    /// @notice Function to verify Engine signature for event upload data, if validated then Ledger contract will be called to execute the event process
    function _eventUploadData(EventTypes.EventUpload calldata data) internal {
        EventTypes.EventUploadData[] calldata events = data.events; // gas saving
        if (events.length != data.count) revert CountNotMatch(events.length, data.count);

        // check engine signature
        bool succ = Signature.eventsUploadEncodeHashVerify(data, engineEventUploadAddress);
        if (!succ) revert SignatureNotMatch();

        // process each event upload
        for (uint256 i = 0; i < data.count; i++) {
            _processEventUpload(events[i]);
        }
    }

    /// @notice Cross-Contract call to Ledger contract to process each event upload according to the event type
    function _processEventUpload(EventTypes.EventUploadData calldata data) internal {
        uint8 bizType = data.bizType;
        if (bizType == 1) {
            // withdraw
            ledger.executeWithdrawAction(abi.decode(data.data, (EventTypes.WithdrawData)), data.eventId);
        } else if (bizType == 2) {
            // settlement
            ledger.executeSettlement(abi.decode(data.data, (EventTypes.Settlement)), data.eventId);
        } else if (bizType == 3) {
            // adl
            ledger.executeAdl(abi.decode(data.data, (EventTypes.Adl)), data.eventId);
        } else if (bizType == 4) {
            // liquidation
            ledger.executeLiquidation(abi.decode(data.data, (EventTypes.Liquidation)), data.eventId);
        } else if (bizType == 5) {
            // fee disuribution
            ledger.executeFeeDistribution(abi.decode(data.data, (EventTypes.FeeDistribution)), data.eventId);
        } else if (bizType == 6) {
            // delegate signer
            ledger.executeDelegateSigner(abi.decode(data.data, (EventTypes.DelegateSigner)), data.eventId);
        } else if (bizType == 7) {
            // delegate withdraw
            ledger.executeDelegateWithdrawAction(abi.decode(data.data, (EventTypes.WithdrawData)), data.eventId);
        } else {
            revert InvalidBizType(bizType);
        }
    }

    /// @notice Function to verify Engine signature for perpetual future price data, if validated then MarketManager contract will be called to execute the market process
    function _perpMarketInfo(MarketTypes.UploadPerpPrice calldata data) internal {
        // check engine signature
        bool succ = Signature.marketUploadEncodeHashVerify(data, engineMarketUploadAddress);
        if (!succ) revert SignatureNotMatch();
        // process perp market info
        marketManager.updateMarketUpload(data);
    }

    /// @notice Function to verify Engine signature for sum unitary fundings data, if validated then MarketManager contract will be called to execute the market process
    function _perpMarketInfo(MarketTypes.UploadSumUnitaryFundings calldata data) internal {
        // check engine signature
        bool succ = Signature.marketUploadEncodeHashVerify(data, engineMarketUploadAddress);
        if (!succ) revert SignatureNotMatch();
        // process perp market info
        marketManager.updateMarketUpload(data);
    }

    /// @notice Cross-Contract call to Ledger contract to process each validated rebalance burn
    function _rebalanceBurnUpload(RebalanceTypes.RebalanceBurnUploadData calldata data) internal {
        // check engine signature
        bool succ = Signature.rebalanceBurnUploadEncodeHashVerify(data, engineRebalanceUploadAddress);
        if (!succ) revert SignatureNotMatch();
        // process rebalance burn
        ledger.executeRebalanceBurn(data);
    }

    /// @notice Cross-Contract call to Ledger contract to process each validated rebalance mint
    function _rebalanceMintUpload(RebalanceTypes.RebalanceMintUploadData calldata data) internal {
        // check engine signature
        bool succ = Signature.rebalanceMintUploadEncodeHashVerify(data, engineRebalanceUploadAddress);
        if (!succ) revert SignatureNotMatch();
        // process rebalance mint
        ledger.executeRebalanceMint(data);
    }

    /// @notice Function to update last operator interaction timestamp
    function _innerPing() internal {
        lastOperatorInteraction = block.timestamp;
    }
}

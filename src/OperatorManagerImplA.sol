// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.26;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "./dataLayout/OperatorManagerDataLayout.sol";
import "./interface/IOperatorManagerImplA.sol";
import "./library/Signature.sol";

/// @title OperatorManager contract, implementation part A contract, for resolve EIP170 limit
/// @author Orderly_Rubick
contract OperatorManagerImplA is IOperatorManagerImplA, OwnableUpgradeable, OperatorManagerDataLayout {
    constructor() {
        _disableInitializers();
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
            ledger.executeProcessValidatedFutures(trades[i]);
        }
        // TODO
        // Need audit of the following code
        // We should change to the transient storage implementation to save gas
        // and increase the tps of trade upload
        // ledger.executeProcessValidatedFuturesBatch(trades);
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

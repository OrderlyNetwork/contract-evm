// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "./dataLayout/LedgerDataLayout.sol";
import "./interface/ILedger.sol";
import "./interface/IVaultManager.sol";
import "./interface/ILedgerCrossChainManager.sol";
import "./interface/IMarketManager.sol";
import "./interface/IFeeManager.sol";
import "./interface/ILedgerImplB.sol";
import "./library/Utils.sol";
import "./library/Signature.sol";
import "./library/typesHelper/AccountTypeHelper.sol";
import "./library/typesHelper/AccountTypePositionHelper.sol";
import "./library/typesHelper/SafeCastHelper.sol";

/// @title Ledger contract, implementation part A contract, for resolve EIP170 limit
/// @author Orderly_Rubick
contract LedgerImplB is ILedgerImplB, OwnableUpgradeable, LedgerDataLayout {
    using AccountTypeHelper for AccountTypes.Account;
    using AccountTypePositionHelper for AccountTypes.PerpPosition;
    using SafeCastHelper for *;
    using SafeCast for uint256;

    bytes32 constant FEE_COLLECTOR_KEY = 0x380b61a03d510578eb69abac2609346d7bf838d9f340f7d0c66cfc65790d7f5e; // uint256(keccak256("FEE_COLLECTOR")) - 1

    constructor() {
        _disableInitializers();
    }

    function executeProcessValidatedFuturesBatch(PerpTypes.FuturesTradeUpload[] calldata trades) external override {
        // init fee collector
        _initFeeCollector();
        uint64 maxTradeId = 0;
        // process each validated perp trades
        for (uint256 i = 0; i < trades.length; i++) {
            PerpTypes.FuturesTradeUpload calldata trade = trades[i];
            _executeProcessValidatedFutures(trade);
        }
        for (uint256 i = trades.length - 1; i > 0; i--) {
            PerpTypes.FuturesTradeUpload calldata trade = trades[i];
            // update last funding update timestamp
            _writeBackLastFundingUpdatedTimestamp(trade);
            if (trade.tradeId > maxTradeId) {
                maxTradeId = trade.tradeId;
            }
        }
        _updateFeeCollectorLastPerpTradeId(maxTradeId); // only update once
        // clean up fee collector
        _cleanUpFeeCollector();
    }

    function _executeProcessValidatedFutures(PerpTypes.FuturesTradeUpload calldata trade) internal {
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
        _feeSwapPosition(perpPosition, trade.symbolHash, trade.fee, trade.sumUnitaryFundings);
        account.lastPerpTradeId = trade.tradeId;
        // update last funding update timestamp
        // marketManager.setLastFundingUpdated(trade.symbolHash, trade.timestamp);
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

    // =================== internal =================== //

    /// @dev get transient storage key base for perp position
    function _getTSPerpPositionKeyBase(bytes32 accountId, bytes32 symbolHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(accountId, symbolHash)) & ~bytes32(uint256(0xff));
    }

    function _initFeeCollector() internal {
        bytes32 feeCollectorAccountId = feeManager.getFeeCollector(IFeeManager.FeeCollectorType.FuturesFeeCollector);
        assembly {
            tstore(FEE_COLLECTOR_KEY, feeCollectorAccountId)
        }
    }

    function _getFeeCollector() internal view returns (bytes32 feeCollector) {
        assembly {
            feeCollector := tload(FEE_COLLECTOR_KEY)
        }
    }

    function _cleanUpFeeCollector() internal {
        assembly {
            tstore(FEE_COLLECTOR_KEY, 0)
        }
    }

    function _writeBackLastFundingUpdatedTimestamp(PerpTypes.FuturesTradeUpload calldata trade) internal {
        // market manager update, only update once
        bytes32 symbolKeyBase = trade.symbolHash;
        if (!_getTSMarketManagerFlag(symbolKeyBase)) {
            marketManager.setLastFundingUpdated(trade.symbolHash, trade.timestamp);
            _setTSMarketManagerFlag(symbolKeyBase, true);
        }
    }

    function _updateFeeCollectorLastPerpTradeId(uint64 tradeId) internal {
        bytes32 feeCollectorAccountId = _getFeeCollector();
        AccountTypes.Account storage feeCollectorAccount = userLedger[feeCollectorAccountId];
        feeCollectorAccount.lastPerpTradeId = tradeId;
    }

    // market manager flag
    function _getTSMarketManagerFlag(bytes32 keyBase) internal view returns (bool flag) {
        bytes32 key = keyBase;
        assembly {
            flag := tload(key)
        }
    }

    function _setTSMarketManagerFlag(bytes32 keyBase, bool flag) internal {
        bytes32 key = keyBase;
        assembly {
            tstore(key, flag)
        }
    }

    function _feeSwapPosition(
        AccountTypes.PerpPosition storage traderPosition,
        bytes32 symbol,
        int128 feeAmount,
        int128 sumUnitaryFundings
    ) internal {
        if (feeAmount == 0) return;
        _perpFeeCollectorDeposit(symbol, feeAmount, sumUnitaryFundings);
        traderPosition.costPosition += feeAmount;
    }

    function _perpFeeCollectorDeposit(bytes32 symbol, int128 amount, int128 sumUnitaryFundings) internal {
        bytes32 feeCollectorAccountId = _getFeeCollector();
        AccountTypes.Account storage feeCollectorAccount = userLedger[feeCollectorAccountId];
        AccountTypes.PerpPosition storage feeCollectorPosition = feeCollectorAccount.perpPositions[symbol];
        feeCollectorPosition.costPosition -= amount;
        feeCollectorPosition.lastSumUnitaryFundings = sumUnitaryFundings;
    }
}

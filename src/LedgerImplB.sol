// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.26;

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

/// @title Ledger contract, implementation part B contract, for resolve EIP170 limit
/// @notice This contract saves gas for method `executeProcessValidatedFuturesBatch` by using transient storage
/// @author Orderly_Rubick
contract LedgerImplB is ILedgerImplB, OwnableUpgradeable, LedgerDataLayout {
    using AccountTypeHelper for AccountTypes.Account;
    using AccountTypePositionHelper for AccountTypes.PerpPosition;
    using SafeCastHelper for *;
    using SafeCast for uint256;

    int128 constant FUNDING_MOVE_RIGHT_PRECISIONS = 1e17; // 1e17
    int128 constant PRICE_QTY_MOVE_RIGHT_PRECISIONS = 1e10; // 1e10
    bytes32 constant FEE_COLLECTOR_KEY = 0x380b61a03d510578eb69abac2609346d7bf838d9f340f7d0c66cfc65790d7f5e; // uint256(keccak256("FEE_COLLECTOR")) - 1
    uint128 constant MASK_ALL_F = 0xffffffffffffffffffffffffffffffff;

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
            _initTS(trade);
            _executeProcessValidatedFutures(trade);
            if (trade.tradeId > maxTradeId) {
                maxTradeId = trade.tradeId;
            }
        }
        _updateFeeCollectorLastPerpTradeId(maxTradeId); // only update once
        for (uint256 i = 0; i < trades.length; i++) {
            PerpTypes.FuturesTradeUpload calldata trade = trades[i];
            _writeBackTS(trade);
        }
        // prevent underflow for i
        for (uint256 i = trades.length; i > 0; i--) {
            PerpTypes.FuturesTradeUpload calldata trade = trades[i - 1];
            // update last funding update timestamp
            _writeBackLastFundingUpdatedTimestamp(trade);
        }
        // clean up last funding update timestamp flag
        for (uint256 i = 0; i < trades.length; i++) {
            PerpTypes.FuturesTradeUpload calldata trade = trades[i];
            _setTSMarketManagerFlag(trade.symbolHash, false);
        }
        // clean up fee collector
        _cleanUpFeeCollector();
    }

    function _executeProcessValidatedFutures(PerpTypes.FuturesTradeUpload calldata trade) internal {
        // validate data first
        if (!vaultManager.getAllowedSymbol(trade.symbolHash)) revert SymbolNotAllowed();
        // do the logic part
        bytes32 keyBase = _getTSPerpPositionKeyBase(trade.accountId, trade.symbolHash);
        AccountTypes.Account storage account = userLedger[trade.accountId];
        {
            (int128 positionQtyTmp, int128 costPositionTmp) = _getTSSecondSlot(keyBase);
            (int128 lastSumUnitaryFundingsTmp, uint128 lastExecutedPriceTmp) = _getTSThirdSlot(keyBase);
            (uint128 averageEntryPriceTmp, int128 openingCostTmp) = _getTSFourthSlot(keyBase);
            costPositionTmp =
                _chargeFundingFee(trade.sumUnitaryFundings, positionQtyTmp, costPositionTmp, lastSumUnitaryFundingsTmp);
            if (trade.tradeQty != 0) {
                (averageEntryPriceTmp, openingCostTmp) = AccountTypePositionHelper.calAverageEntryPrice(
                    positionQtyTmp, openingCostTmp, trade.tradeQty, trade.executedPrice.toInt128(), 0
                );
            }
            positionQtyTmp += trade.tradeQty;
            costPositionTmp += trade.notional;
            lastExecutedPriceTmp = trade.executedPrice;
            // fee_swap_position
            costPositionTmp = _feeSwapPosition(trade.symbolHash, trade.fee, trade.sumUnitaryFundings, costPositionTmp);
            account.lastPerpTradeId = trade.tradeId;
            // write back tmp values
            _setTSSecondSlot(keyBase, positionQtyTmp, costPositionTmp);
            _setTSThirdSlot(keyBase, trade.sumUnitaryFundings, lastExecutedPriceTmp);
            _setTSFourthSlot(keyBase, averageEntryPriceTmp, openingCostTmp);
        }
        // update last funding update timestamp in write-back phase
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

    // naive design:
    // Account PerpPosition:
    // _getTSPerpPosition: not used
    // _getTSPerpPosition + 1: bool, a flag whether the position is set
    // _getTSPerpPosition + 2: int128 + int128, positionQty + costPosition
    // _getTSPerpPosition + 3: int128 + uint128, lastSumUnitaryFundings + lastExecutedPrice
    // _getTSPerpPosition + 4: uint128 + int128, averageEntryPrice + openingCost
    // Fee PerpPosition:
    // _getTSPerpPosition + 1: bool + int128, a flag whether the position is set + lastSumUnitaryFundings
    // _getTSPerpPosition + 2: int128 + int128, positionQty + costPosition
    function _initTS(PerpTypes.FuturesTradeUpload calldata trade) internal {
        // perpPosition init
        bytes32 keyBase = _getTSPerpPositionKeyBase(trade.accountId, trade.symbolHash);
        (bool flag) = _getTSFirstSlot(keyBase);
        if (!flag) {
            // should init and set flag
            AccountTypes.Account storage account = userLedger[trade.accountId];
            AccountTypes.PerpPosition storage perpPosition = account.perpPositions[trade.symbolHash];
            _setTSFirstSlot(keyBase, true);
            _setTSSecondSlot(keyBase, perpPosition.positionQty, perpPosition.costPosition);
            _setTSThirdSlot(keyBase, perpPosition.lastSumUnitaryFundings, perpPosition.lastExecutedPrice);
            _setTSFourthSlot(keyBase, perpPosition.averageEntryPrice, perpPosition.openingCost);
        }

        // feeCollector init
        bytes32 feeCollectorAccountId = _getFeeCollector();
        bytes32 feeKeyBase = _getTSPerpPositionKeyBase(feeCollectorAccountId, trade.symbolHash);
        (flag,) = _getFeeTSFirstSlot(feeKeyBase);
        if (!flag) {
            AccountTypes.Account storage feeCollectorAccount = userLedger[feeCollectorAccountId];
            AccountTypes.PerpPosition storage feeCollectorPosition = feeCollectorAccount.perpPositions[trade.symbolHash];
            _setFeeTSFirstSlot(feeKeyBase, true, feeCollectorPosition.lastSumUnitaryFundings);
            _setFeeTSSecondSlot(feeKeyBase, feeCollectorPosition.positionQty, feeCollectorPosition.costPosition);
        }
    }

    function _writeBackTS(PerpTypes.FuturesTradeUpload calldata trade) internal {
        // perpPosition write back
        bytes32 keyBase = _getTSPerpPositionKeyBase(trade.accountId, trade.symbolHash);
        (bool flag) = _getTSFirstSlot(keyBase);
        if (flag) {
            // should write back
            AccountTypes.Account storage account = userLedger[trade.accountId];
            AccountTypes.PerpPosition storage perpPosition = account.perpPositions[trade.symbolHash];
            int128 t1;
            int128 t2;
            uint128 t3;
            (t1, t2) = _getTSSecondSlot(keyBase);
            perpPosition.positionQty = t1;
            perpPosition.costPosition = t2;
            (t1, t3) = _getTSThirdSlot(keyBase);
            perpPosition.lastSumUnitaryFundings = t1;
            perpPosition.lastExecutedPrice = t3;
            (t3, t2) = _getTSFourthSlot(keyBase);
            perpPosition.averageEntryPrice = t3;
            perpPosition.openingCost = t2;
            // clean up
            _setTSFirstSlot(keyBase, false);
            _setTSSecondSlot(keyBase, 0, 0);
            _setTSThirdSlot(keyBase, 0, 0);
            _setTSFourthSlot(keyBase, 0, 0);
        }
        // feeCollector write back
        bytes32 feeCollectorAccountId = _getFeeCollector();
        bytes32 feeKeyBase = _getTSPerpPositionKeyBase(feeCollectorAccountId, trade.symbolHash);
        (bool flagFee, int128 lastSumUnitaryFundings) = _getFeeTSFirstSlot(feeKeyBase);
        if (flagFee) {
            AccountTypes.Account storage feeCollectorAccount = userLedger[feeCollectorAccountId];
            AccountTypes.PerpPosition storage feeCollectorPosition = feeCollectorAccount.perpPositions[trade.symbolHash];
            feeCollectorPosition.lastSumUnitaryFundings = lastSumUnitaryFundings;
            (, feeCollectorPosition.costPosition) = _getFeeTSSecondSlot(feeKeyBase);
            // clean up
            _setFeeTSFirstSlot(feeKeyBase, false, 0);
            _setFeeTSSecondSlot(feeKeyBase, 0, 0);
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

    // =================== transient storage =================== //

    // for Account PerpPosition

    // bool
    function _getTSFirstSlot(bytes32 keyBase) internal view returns (bool v1) {
        bytes32 key = keyBase | bytes32(uint256(1));
        assembly {
            v1 := tload(key)
        }
    }

    // int128 + int128
    function _getTSSecondSlot(bytes32 keyBase) internal view returns (int128 v1, int128 v2) {
        bytes32 key = keyBase | bytes32(uint256(2));
        assembly {
            let tmp := tload(key)
            v1 := shr(128, tmp)
            v2 := and(tmp, MASK_ALL_F)
        }
    }

    // int128 + uint128
    function _getTSThirdSlot(bytes32 keyBase) internal view returns (int128 v1, uint128 v2) {
        bytes32 key = keyBase | bytes32(uint256(3));
        assembly {
            let tmp := tload(key)
            v1 := shr(128, tmp)
            v2 := and(tmp, MASK_ALL_F)
        }
    }

    // uint128 + int128
    function _getTSFourthSlot(bytes32 keyBase) internal view returns (uint128 v1, int128 v2) {
        bytes32 key = keyBase | bytes32(uint256(4));
        assembly {
            let tmp := tload(key)
            v1 := shr(128, tmp)
            v2 := and(tmp, MASK_ALL_F)
        }
    }

    function _setTSFirstSlot(bytes32 keyBase, bool v1) internal {
        bytes32 key = keyBase | bytes32(uint256(1));
        assembly {
            tstore(key, v1)
        }
    }

    function _setTSSecondSlot(bytes32 keyBase, int128 v1, int128 v2) internal {
        bytes32 key = keyBase | bytes32(uint256(2));
        assembly {
            tstore(key, or(shl(128, v1), and(v2, MASK_ALL_F)))
        }
    }

    function _setTSThirdSlot(bytes32 keyBase, int128 v1, uint128 v2) internal {
        bytes32 key = keyBase | bytes32(uint256(3));
        assembly {
            tstore(key, or(shl(128, v1), and(v2, MASK_ALL_F)))
        }
    }

    function _setTSFourthSlot(bytes32 keyBase, uint128 v1, int128 v2) internal {
        bytes32 key = keyBase | bytes32(uint256(4));
        assembly {
            tstore(key, or(shl(128, v1), and(v2, MASK_ALL_F)))
        }
    }

    // For Fee PerpPosition

    // bool + int128
    function _getFeeTSFirstSlot(bytes32 keyBase) internal view returns (bool v1, int128 v2) {
        bytes32 key = keyBase | bytes32(uint256(1));
        assembly {
            let tmp := tload(key)
            v1 := shr(128, tmp)
            v2 := and(tmp, MASK_ALL_F)
        }
    }

    // int128 + int128
    function _getFeeTSSecondSlot(bytes32 keyBase) internal view returns (int128 v1, int128 v2) {
        bytes32 key = keyBase | bytes32(uint256(2));
        assembly {
            let tmp := tload(key)
            v1 := shr(128, tmp)
            v2 := and(tmp, MASK_ALL_F)
        }
    }

    function _setFeeTSFirstSlot(bytes32 keyBase, bool v1, int128 v2) internal {
        bytes32 key = keyBase | bytes32(uint256(1));
        assembly {
            tstore(key, or(shl(128, v1), and(v2, MASK_ALL_F)))
        }
    }

    function _setFeeTSSecondSlot(bytes32 keyBase, int128 v1, int128 v2) internal {
        bytes32 key = keyBase | bytes32(uint256(2));
        assembly {
            tstore(key, or(shl(128, v1), and(v2, MASK_ALL_F)))
        }
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

    function _feeSwapPosition(bytes32 symbol, int128 feeAmount, int128 sumUnitaryFundings, int128 costPositionOld)
        internal
        returns (int128 costPositionNew)
    {
        if (feeAmount == 0) return costPositionOld;
        _perpFeeCollectorDeposit(symbol, feeAmount, sumUnitaryFundings);
        costPositionNew = costPositionOld + feeAmount;
    }

    function _chargeFundingFee(
        int128 sumUnitaryFundings,
        int128 positionQtyOld,
        int128 costPositionOld,
        int128 lastSumUnitaryFundingsOld
    ) internal pure returns (int128 costPositionNew) {
        int128 accruedFeeUnconverted = positionQtyOld * (sumUnitaryFundings - lastSumUnitaryFundingsOld);
        int128 accruedFee = accruedFeeUnconverted / FUNDING_MOVE_RIGHT_PRECISIONS;
        int128 remainder = accruedFeeUnconverted - (accruedFee * FUNDING_MOVE_RIGHT_PRECISIONS);
        if (remainder > 0) {
            accruedFee += 1;
        }
        costPositionNew = costPositionOld + accruedFee;
    }

    function _perpFeeCollectorDeposit(bytes32 symbol, int128 amount, int128 sumUnitaryFundings) internal {
        bytes32 feeCollectorAccountId = _getFeeCollector();
        bytes32 feeKeyBase = _getTSPerpPositionKeyBase(feeCollectorAccountId, symbol);
        (int128 positionQty, int128 costPosition) = _getTSSecondSlot(feeKeyBase);
        _setFeeTSFirstSlot(feeKeyBase, true, sumUnitaryFundings);
        _setFeeTSSecondSlot(feeKeyBase, positionQty, costPosition - amount);
    }
}

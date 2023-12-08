// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "./DecompressorExtension.sol";
import "../interface/IOperatorManagerZip.sol";
import "../dataLayout/OperatorManagerZipDataLayout.sol";
import "../interface/IOperatorManager.sol";

/// @title Operator call this contract to decompress calldata
/// @author Orderly_Zion, Orderly_Rubick
/// @notice OperatorManagerZip is responsible for decompressing calldata size to save L1 gas, only called by operator.
/// @notice This contract could be deprecated after Cancun upgrade
contract OperatorManagerZip is
    OwnableUpgradeable,
    DecompressorExtension,
    IOperatorManagerZip,
    OperatorManagerZipDataLayout
{
    constructor() {
        _disableInitializers();
    }

    modifier onlyOperator() {
        if (msg.sender != operatorAddress) revert OnlyOperatorCanCall();
        _;
    }

    function initialize() external override initializer {
        __Ownable_init();
    }

    function setOperator(address _operatorAddress) external override onlyOwner {
        if (_operatorAddress == address(0)) revert AddressZero();

        emit ChangeOperator(operatorAddress, _operatorAddress);
        operatorAddress = _operatorAddress;
    }

    function setOpeartorManager(address _operatorManager) external override onlyOwner {
        if (_operatorManager == address(0)) revert AddressZero();

        emit ChangeOperatorManager(address(operatorManager), _operatorManager);
        operatorManager = IOperatorManager(_operatorManager);
    }

    function setSymbol(bytes32 symbolHash, uint8 symbolId) external override onlyOperator {
        symbolId2Hash[symbolId] = symbolHash;
    }

    function decodeFuturesTradeUploadData(bytes calldata data) external override onlyOperator {
        bytes memory raw = _decompressed(data);
        PerpTypesZip.FuturesTradeUploadDataZip memory decoded =
            abi.decode(raw, (PerpTypesZip.FuturesTradeUploadDataZip));
        PerpTypes.FuturesTradeUploadData memory decodedData = PerpTypes.FuturesTradeUploadData({
            r: decoded.r,
            s: decoded.s,
            v: decoded.v,
            batchId: decoded.batchId,
            count: decoded.count,
            trades: new PerpTypes.FuturesTradeUpload[](decoded.count)
        });
        for (uint8 i = 0; i < decoded.count; i++) {
            PerpTypesZip.FuturesTradeUploadZip memory zipData = decoded.trades[i];
            // notional = tradeQty * executedPrice / 1e10, where tradeQty is int128, executedPrice is uint128
            // no worry about overflow, we expand the notional to int256
            int128 notional = int128(int256(zipData.tradeQty) * int256(uint256((zipData.executedPrice))) / 1e10);
            decodedData.trades[i] = PerpTypes.FuturesTradeUpload({
                accountId: zipData.accountId,
                symbolHash: symbolId2Hash[zipData.symbolId],
                feeAssetHash: 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa, // hash of "USDC"
                tradeQty: zipData.tradeQty,
                notional: notional,
                executedPrice: zipData.executedPrice,
                fee: zipData.fee,
                sumUnitaryFundings: zipData.sumUnitaryFundings,
                tradeId: zipData.tradeId,
                matchId: zipData.matchId,
                timestamp: zipData.timestamp,
                side: zipData.tradeQty < 0 // buy (false) or sell (true)
            });
        }
        IOperatorManager(operatorManager).futuresTradeUpload(decodedData);
    }
}

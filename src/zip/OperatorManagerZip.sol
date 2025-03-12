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
    bytes32 constant HASH_OF_USDC = 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa;

    constructor() {
        _disableInitializers();
    }

    modifier onlyOperator() {
        if (msg.sender != zipOperatorAddress) revert OnlyOperatorCanCall();
        _;
    }

    /// @notice check non-zero address
    modifier nonZeroAddress(address _address) {
        if (_address == address(0)) revert AddressZero();
        _;
    }

    function initialize() external override initializer {
        __Ownable_init();
    }

    function setOperator(address _operatorAddress) external override onlyOwner nonZeroAddress(_operatorAddress) {
        emit ChangeOperator(zipOperatorAddress, _operatorAddress);
        zipOperatorAddress = _operatorAddress;
    }

    function setOpeartorManager(address _operatorManager)
        external
        override
        onlyOwner
        nonZeroAddress(_operatorManager)
    {
        emit ChangeOperatorManager(address(operatorManager), _operatorManager);
        operatorManager = IOperatorManager(_operatorManager);
    }

    function setSymbol(bytes32 symbolHash, uint8 symbolId) external override onlyOwner {
        symbolId2Hash[symbolId] = symbolHash;
    }

    function decodeFuturesTradeUploadData(bytes calldata data) external override onlyOperator {
        PerpTypes.FuturesTradeUploadData memory decodedData = _decodeFuturesTradeUploadData(data);
        IOperatorManager(operatorManager).futuresTradeUpload(decodedData);
    }

    function decodeEventUploadData(bytes calldata data) external override onlyOperator {
        EventTypes.EventUpload memory decodedData = _decodeEventUploadData(data);
        IOperatorManager(operatorManager).eventUpload(decodedData);
    }

    function initSymbolId2Hash() external override onlyOwner {
        // https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/428180072/EVM+Listing+Symbols
        symbolId2Hash[1] = 0x5a8133e52befca724670dbf2cade550c522c2410dd5b1189df675e99388f509d;
        symbolId2Hash[2] = 0x7e83089239db756ee233fa8972addfea16ae653db0f692e4851aed546b21caeb;
        symbolId2Hash[3] = 0x2f1991e99a4e22a9e95ff1b67aee336b4047dc47612e36674fa23eb8c6017f2e;
        symbolId2Hash[4] = 0x3e5bb1a69a9094f1b2ccad4f39a7d70e2a29f08c2c0eac87b970ea650ac12ec2;
        symbolId2Hash[5] = 0xb5ec44c9e46c5ae2fa0473eb8c466c97ec83dd5f4eddf66f31e83b512cff503c;

        symbolId2Hash[6] = 0x01bec50d553af75d1a2204c760570f374c438885070eb995500c7a08fc5a9ec2;
        symbolId2Hash[7] = 0xe31e58f63b7cc1ad056bda9f1be47bf0ad0891a03d3a759f68c7814241a48907;
        symbolId2Hash[8] = 0xc3d5ec779f548bc3d82ab3438416db751e7e1946827b31eeb1bd08e367278281;
        symbolId2Hash[9] = 0xcaf4dffbbf83b8f5c74bb2946baeb3da1c6c7fc6290a899b18e95bb6f11c0503;
        symbolId2Hash[10] = 0xa84558a42cda72af9bb348e8fc6cdfca9b3ddd885f1b8877abbc33beafc8bfec;

        symbolId2Hash[11] = 0x76bba29822652c557a30fe45ff09e7e244e3819699df0c0995622c12db16e72d;
        symbolId2Hash[12] = 0xd44817bf72a4d9b5e277bfec92619466999b1adbd9f3c52621d1651ac354b09c;
        symbolId2Hash[13] = 0x2aa4f612cf7a91de02395cadb419d3bf578130509b35b69c05738860e5b74637;
        symbolId2Hash[14] = 0x5d0471b083610a6f3b572fc8b0f759c5628e74159816681fb7d927b9263de60b;
        symbolId2Hash[15] = 0xa2adc016e890b4fbbf161c7eaeb615b893e4fbeceae918fa7bf16cc40d46610b;
    }

    // empty function, for generate ABI for struct `PerpTypesZip.FuturesTradeUploadDataZip`
    function placeholder(PerpTypesZip.FuturesTradeUploadDataZip calldata zip) external {}
    function placeholder2(EventTypesZip.EventUpload calldata zip) external {}

    // internal function
    function calcNotional(int128 tradeQty, uint128 executedPrice) internal pure returns (int128) {
        // notional = tradeQty * executedPrice / 1e10, where tradeQty is int128, executedPrice is uint128
        // no worry about overflow, we expand the notional to int256
        return int128(int256(tradeQty) * int256(uint256((executedPrice))) / 1e10);
    }

    function _decodeFuturesTradeUploadData(bytes calldata data)
        internal
        view
        returns (PerpTypes.FuturesTradeUploadData memory)
    {
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
            if (symbolId2Hash[zipData.symbolId] == 0x0) revert SymbolNotRegister();
            // notional = tradeQty * executedPrice / 1e10, where tradeQty is int128, executedPrice is uint128
            // no worry about overflow, we expand the notional to int256
            decodedData.trades[i] = PerpTypes.FuturesTradeUpload({
                accountId: zipData.accountId,
                symbolHash: symbolId2Hash[zipData.symbolId],
                feeAssetHash: HASH_OF_USDC,
                tradeQty: zipData.tradeQty,
                notional: calcNotional(zipData.tradeQty, zipData.executedPrice),
                executedPrice: zipData.executedPrice,
                fee: zipData.fee,
                sumUnitaryFundings: zipData.sumUnitaryFundings,
                tradeId: zipData.tradeId,
                matchId: zipData.matchId,
                timestamp: zipData.timestamp,
                side: zipData.tradeQty < 0 // buy (false) or sell (true)
            });
        }
        return decodedData;
    }

    function _decodeEventUploadData(bytes calldata data) internal view returns (EventTypes.EventUpload memory) {
        bytes memory raw = _decompressed(data);
        EventTypesZip.EventUpload memory decoded = abi.decode(raw, (EventTypesZip.EventUpload));
        EventTypes.EventUpload memory decodedData = EventTypes.EventUpload({
            events: new EventTypes.EventUploadData[](decoded.count),
            r: decoded.r,
            s: decoded.s,
            v: decoded.v,
            count: decoded.count,
            batchId: decoded.batchId
        });
        for (uint8 i = 0; i < decoded.count; i++) {
            EventTypesZip.EventUploadData memory zipData = decoded.events[i];
            if (zipData.bizType == 1 || zipData.bizType == 7) {
                EventTypesZip.WithdrawData memory withdrawZip = abi.decode(zipData.data, (EventTypesZip.WithdrawData));
                decodedData.events[i] = EventTypes.EventUploadData({
                    bizType: zipData.bizType,
                    eventId: zipData.eventId,
                    data: abi.encode(
                        EventTypes.WithdrawData({
                            tokenAmount: withdrawZip.tokenAmount,
                            fee: withdrawZip.fee,
                            chainId: withdrawZip.chainId,
                            accountId: withdrawZip.accountId,
                            r: withdrawZip.r,
                            s: withdrawZip.s,
                            v: withdrawZip.v,
                            sender: withdrawZip.sender,
                            withdrawNonce: withdrawZip.withdrawNonce,
                            receiver: withdrawZip.receiver,
                            timestamp: withdrawZip.timestamp,
                            brokerId: withdrawZip.brokerId,
                            tokenSymbol: "USDC"
                        })
                    )
                });
            } else if (zipData.bizType == 2) {
                EventTypesZip.Settlement memory settlementZip = abi.decode(zipData.data, (EventTypesZip.Settlement));
                EventTypes.Settlement memory decodedSettlement = EventTypes.Settlement({
                    accountId: settlementZip.accountId,
                    settledAssetHash: settlementZip.settledAssetHash,
                    insuranceAccountId: settlementZip.insuranceAccountId,
                    settledAmount: settlementZip.settledAmount,
                    insuranceTransferAmount: settlementZip.insuranceTransferAmount,
                    timestamp: settlementZip.timestamp,
                    settlementExecutions: new EventTypes.SettlementExecution[](settlementZip.settlementExecutions.length)
                });
                for (uint8 j = 0; j < settlementZip.settlementExecutions.length; j++) {
                    EventTypesZip.SettlementExecution memory executionZip = settlementZip.settlementExecutions[j];
                    decodedSettlement.settlementExecutions[j] = EventTypes.SettlementExecution({
                        symbolHash: symbolId2Hash[executionZip.symbolId],
                        markPrice: executionZip.markPrice,
                        sumUnitaryFundings: executionZip.sumUnitaryFundings,
                        settledAmount: executionZip.settledAmount
                    });
                }
                decodedData.events[i] = EventTypes.EventUploadData({
                    bizType: zipData.bizType,
                    eventId: zipData.eventId,
                    data: abi.encode(decodedSettlement)
                });
            } else if (zipData.bizType == 3) {
                EventTypesZip.Adl memory adlZip = abi.decode(zipData.data, (EventTypesZip.Adl));
                decodedData.events[i] = EventTypes.EventUploadData({
                    bizType: zipData.bizType,
                    eventId: zipData.eventId,
                    data: abi.encode(
                        EventTypes.Adl({
                            accountId: adlZip.accountId,
                            insuranceAccountId: adlZip.insuranceAccountId,
                            symbolHash: symbolId2Hash[adlZip.symbolId],
                            positionQtyTransfer: adlZip.positionQtyTransfer,
                            costPositionTransfer: adlZip.costPositionTransfer,
                            adlPrice: adlZip.adlPrice,
                            sumUnitaryFundings: adlZip.sumUnitaryFundings,
                            timestamp: adlZip.timestamp
                        })
                    )
                });
            } else if (zipData.bizType == 4) {
                EventTypesZip.Liquidation memory liquidationZip = abi.decode(zipData.data, (EventTypesZip.Liquidation));
                EventTypes.Liquidation memory decodedLiquidation = EventTypes.Liquidation({
                    liquidatedAccountId: liquidationZip.liquidatedAccountId,
                    insuranceAccountId: liquidationZip.insuranceAccountId,
                    liquidatedAssetHash: liquidationZip.liquidatedAssetHash,
                    insuranceTransferAmount: liquidationZip.insuranceTransferAmount,
                    timestamp: liquidationZip.timestamp,
                    liquidationTransfers: new EventTypes.LiquidationTransfer[](liquidationZip.liquidationTransfers.length)
                });
                for (uint8 j = 0; j < liquidationZip.liquidationTransfers.length; j++) {
                    EventTypesZip.LiquidationTransfer memory transferZip = liquidationZip.liquidationTransfers[j];
                    decodedLiquidation.liquidationTransfers[j] = EventTypes.LiquidationTransfer({
                        liquidatorAccountId: transferZip.liquidatorAccountId,
                        symbolHash: symbolId2Hash[transferZip.symbolId],
                        positionQtyTransfer: transferZip.positionQtyTransfer,
                        costPositionTransfer: transferZip.costPositionTransfer,
                        liquidatorFee: transferZip.liquidatorFee,
                        insuranceFee: transferZip.insuranceFee,
                        liquidationFee: transferZip.liquidationFee,
                        markPrice: transferZip.markPrice,
                        sumUnitaryFundings: transferZip.sumUnitaryFundings,
                        liquidationTransferId: transferZip.liquidationTransferId
                    });
                }
                decodedData.events[i] = EventTypes.EventUploadData({
                    bizType: zipData.bizType,
                    eventId: zipData.eventId,
                    data: abi.encode(decodedLiquidation)
                });
            } else if (zipData.bizType == 5) {
                EventTypesZip.FeeDistribution memory feeDistributionZip =
                    abi.decode(zipData.data, (EventTypesZip.FeeDistribution));
                decodedData.events[i] = EventTypes.EventUploadData({
                    bizType: zipData.bizType,
                    eventId: zipData.eventId,
                    data: abi.encode(
                        EventTypes.FeeDistribution({
                            fromAccountId: feeDistributionZip.fromAccountId,
                            toAccountId: feeDistributionZip.toAccountId,
                            amount: feeDistributionZip.amount,
                            tokenHash: feeDistributionZip.tokenHash
                        })
                    )
                });
            } else if (zipData.bizType == 6) {
                EventTypesZip.DelegateSigner memory delegateSignerZip =
                    abi.decode(zipData.data, (EventTypesZip.DelegateSigner));
                decodedData.events[i] = EventTypes.EventUploadData({
                    bizType: zipData.bizType,
                    eventId: zipData.eventId,
                    data: abi.encode(
                        EventTypes.DelegateSigner({
                            delegateSigner: delegateSignerZip.delegateSigner,
                            delegateContract: delegateSignerZip.delegateContract,
                            brokerHash: delegateSignerZip.brokerHash,
                            chainId: delegateSignerZip.chainId
                        })
                    )
                });
            }
        }
        return decodedData;
    }
}

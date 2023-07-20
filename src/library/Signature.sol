// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./types/PerpTypes.sol";
import "./types/EventTypes.sol";
import "./types/MarketTypes.sol";

library Signature {
    function verifyWithdraw(address sender, EventTypes.WithdrawData memory data) internal view returns (bool) {
        bytes32 typeHash =
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

        bytes32 eip712DomainHash = keccak256(
            abi.encode(typeHash, keccak256(bytes("Orderly")), keccak256(bytes("1")), data.chainId, address(this))
        );

        bytes32 hashStruct = keccak256(
            abi.encode(
                keccak256(
                    "Withdraw(string brokerId,uint256 chainId,address receiver,string token,uint256 amount,uint64 withdrawNonce,uint64 timestamp)"
                ),
                keccak256(abi.encodePacked(data.brokerId)),
                data.chainId,
                data.receiver,
                keccak256(abi.encodePacked(data.tokenSymbol)),
                data.tokenAmount,
                data.withdrawNonce,
                data.timestamp
            )
        );

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", eip712DomainHash, hashStruct));
        address signer = ecrecover(hash, data.v, data.r, data.s);
        return signer == sender && signer != address(0);
    }

    function getEthSignedMessageHash(bytes32 _messageHash) internal pure returns (bytes32) {
        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash));
    }

    function verify(bytes32 hash, bytes32 r, bytes32 s, uint8 v, address signer) internal pure returns (bool) {
        return ecrecover(hash, v, r, s) == signer;
    }

    function perpUploadEncodeHashVerify(PerpTypes.FuturesTradeUploadData memory data, address signer)
        internal
        pure
        returns (bool)
    {
        bytes memory encoded = abi.encode(data.batchId, data.count, data.trades);
        bytes32 h = getEthSignedMessageHash(keccak256(encoded));
        return verify(h, data.r, data.s, data.v, signer);
    }

    struct WithdrawDataSignature {
        uint64 eventId; // flat map to this
        string brokerId;
        bytes32 accountId;
        uint256 chainId;
        address sender;
        address receiver;
        string token;
        uint128 tokenAmount;
        uint128 fee;
        uint64 withdrawNonce;
        uint64 timestamp;
    }

    struct SettlementSignature {
        uint64 eventId; // flat map to this
        bytes32 accountId;
        int128 settledAmount;
        bytes32 settledAssetHash;
        bytes32 insuranceAccountId;
        uint128 insuranceTransferAmount;
        EventTypes.SettlementExecution[] settlementExecutions;
        uint64 timestamp;
    }

    struct AdlSignature {
        uint64 eventId; // flat map to this
        bytes32 accountId;
        bytes32 insuranceAccountId;
        bytes32 symbolHash;
        int128 positionQtyTransfer;
        int128 costPositionTransfer;
        uint128 adlPrice;
        int128 sumUnitaryFundings;
        uint64 timestamp;
    }

    struct LiquidationSignature {
        uint64 eventId; // flat map to this
        bytes32 liquidatedAccountId;
        bytes32 insuranceAccountId;
        uint128 insuranceTransferAmount;
        bytes32 liquidatedAssetHash;
        EventTypes.LiquidationTransfer[] liquidationTransfers;
        uint64 timestamp;
    }

    struct EventUploadSignature {
        uint64 batchId;
        WithdrawDataSignature[] withdraws;
        SettlementSignature[] settlements;
        AdlSignature[] adls;
        LiquidationSignature[] liquidations;
    }

    function eventsUploadEncodeHash(EventTypes.EventUpload memory data) internal pure returns (bytes memory) {
        uint8[] memory countArray = new uint8[](4);
        uint8[] memory countArray2 = new uint8[](4);
        uint256 len = data.events.length;
        for (uint256 i = 0; i < len; i++) {
            countArray[data.events[i].bizType - 1]++;
        }
        EventUploadSignature memory eventUploadSignature = EventUploadSignature({
            batchId: data.batchId,
            withdraws: new WithdrawDataSignature[](countArray[0]),
            settlements: new SettlementSignature[](countArray[1]),
            adls: new AdlSignature[](countArray[2]),
            liquidations: new LiquidationSignature[](countArray[3])
        });
        for (uint256 i = 0; i < len; i++) {
            EventTypes.EventUploadData memory eventUploadData = data.events[i];
            if (eventUploadData.bizType == 1) {
                EventTypes.WithdrawData memory withdrawData =
                    abi.decode(eventUploadData.data, (EventTypes.WithdrawData));
                WithdrawDataSignature memory withdrawDataSignature = WithdrawDataSignature({
                    eventId: eventUploadData.eventId,
                    brokerId: withdrawData.brokerId,
                    accountId: withdrawData.accountId,
                    chainId: withdrawData.chainId,
                    sender: withdrawData.sender,
                    receiver: withdrawData.receiver,
                    token: withdrawData.tokenSymbol,
                    tokenAmount: withdrawData.tokenAmount,
                    fee: withdrawData.fee,
                    withdrawNonce: withdrawData.withdrawNonce,
                    timestamp: withdrawData.timestamp
                });
                eventUploadSignature.withdraws[countArray2[0]] = withdrawDataSignature;
                countArray2[0]++;
            } else if (eventUploadData.bizType == 2) {
                EventTypes.Settlement memory settlement = abi.decode(eventUploadData.data, (EventTypes.Settlement));
                SettlementSignature memory settlementSignature = SettlementSignature({
                    eventId: eventUploadData.eventId,
                    accountId: settlement.accountId,
                    settledAmount: settlement.settledAmount,
                    settledAssetHash: settlement.settledAssetHash,
                    insuranceAccountId: settlement.insuranceAccountId,
                    insuranceTransferAmount: settlement.insuranceTransferAmount,
                    settlementExecutions: settlement.settlementExecutions,
                    timestamp: settlement.timestamp
                });
                eventUploadSignature.settlements[countArray2[1]] = settlementSignature;
                countArray2[1]++;
            } else if (eventUploadData.bizType == 3) {
                EventTypes.Adl memory adl = abi.decode(eventUploadData.data, (EventTypes.Adl));
                AdlSignature memory adlSignature = AdlSignature({
                    eventId: eventUploadData.eventId,
                    accountId: adl.accountId,
                    insuranceAccountId: adl.insuranceAccountId,
                    symbolHash: adl.symbolHash,
                    positionQtyTransfer: adl.positionQtyTransfer,
                    costPositionTransfer: adl.costPositionTransfer,
                    adlPrice: adl.adlPrice,
                    sumUnitaryFundings: adl.sumUnitaryFundings,
                    timestamp: adl.timestamp
                });
                eventUploadSignature.adls[countArray2[2]] = adlSignature;
                countArray2[2]++;
            } else if (eventUploadData.bizType == 4) {
                EventTypes.Liquidation memory liquidation = abi.decode(eventUploadData.data, (EventTypes.Liquidation));
                LiquidationSignature memory liquidationSignature = LiquidationSignature({
                    eventId: eventUploadData.eventId,
                    liquidatedAccountId: liquidation.liquidatedAccountId,
                    insuranceAccountId: liquidation.insuranceAccountId,
                    insuranceTransferAmount: liquidation.insuranceTransferAmount,
                    liquidatedAssetHash: liquidation.liquidatedAssetHash,
                    liquidationTransfers: liquidation.liquidationTransfers,
                    timestamp: liquidation.timestamp
                });
                eventUploadSignature.liquidations[countArray2[3]] = liquidationSignature;
                countArray2[3]++;
            }
        }
        bytes memory encoded = abi.encode(
            eventUploadSignature.batchId,
            eventUploadSignature.withdraws,
            eventUploadSignature.settlements,
            eventUploadSignature.adls,
            eventUploadSignature.liquidations
        );
        return encoded;
    }

    function eventsUploadEncodeHashVerify(EventTypes.EventUpload memory data, address signer)
        internal
        pure
        returns (bool)
    {
        bytes32 h = getEthSignedMessageHash(keccak256(eventsUploadEncodeHash(data)));
        return verify(h, data.r, data.s, data.v, signer);
    }

    function marketCfgUploadEncodeHashVerify(
        bytes32 r,
        bytes32 s,
        uint8 v,
        MarketTypes.PerpPriceInner memory data,
        address signer
    ) internal pure returns (bool) {
        bytes memory encoded = abi.encode(data.maxTimestamp, data.perpPrices);
        bytes32 h = getEthSignedMessageHash(keccak256(encoded));
        return verify(h, r, s, v, signer);
    }

    function marketCfgUploadEncodeHashVerify(
        bytes32 r,
        bytes32 s,
        uint8 v,
        MarketTypes.SumUnitaryFundingsInner memory data,
        address signer
    ) internal pure returns (bool) {
        bytes memory encoded = abi.encode(data.maxTimestamp, data.sumUnitaryFundings);
        bytes32 h = getEthSignedMessageHash(keccak256(encoded));
        return verify(h, r, s, v, signer);
    }
}

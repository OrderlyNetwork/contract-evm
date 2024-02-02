// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "./types/PerpTypes.sol";
import "./types/EventTypes.sol";
import "./types/MarketTypes.sol";
import "./types/RebalanceTypes.sol";

/// @title Signature library
/// @author Orderly_Rubick, Orderly_Zion
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
        return ECDSA.recover(hash, data.v, data.r, data.s) == sender;
    }

    function verifyDelegateWithdraw(address delegateSigner, EventTypes.WithdrawData memory data)
        internal
        view
        returns (bool)
    {
        bytes32 typeHash =
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

        bytes32 eip712DomainHash = keccak256(
            abi.encode(typeHash, keccak256(bytes("Orderly")), keccak256(bytes("1")), data.chainId, address(this))
        );

        bytes32 hashStruct = keccak256(
            abi.encode(
                keccak256(
                    "DelegateWithdraw(address delegateContract,string brokerId,uint256 chainId,address receiver,string token,uint256 amount,uint64 withdrawNonce,uint64 timestamp)"
                ),
                data.sender,
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
        return ECDSA.recover(hash, data.v, data.r, data.s) == delegateSigner;
    }

    function verify(bytes32 hash, bytes32 r, bytes32 s, uint8 v, address signer) internal pure returns (bool) {
        return ECDSA.recover(hash, v, r, s) == signer;
    }

    function perpUploadEncodeHashVerify(PerpTypes.FuturesTradeUploadData memory data, address signer)
        internal
        pure
        returns (bool)
    {
        bytes memory encoded = abi.encode(data.batchId, data.count, data.trades);
        bytes32 h = ECDSA.toEthSignedMessageHash(keccak256(encoded));
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

    struct FeeDistributionSignature {
        uint64 eventId; // flat map to this
        bytes32 fromAccountId;
        bytes32 toAccountId;
        uint128 amount;
        bytes32 tokenHash;
    }

    struct DelegeteSignerSignature {
        uint64 eventId; // flat map to this
        address delegateSigner;
        address delegateContract;
        bytes32 brokerHash;
        uint256 chainId;
    }

    struct EventUploadSignature {
        uint64 batchId;
        WithdrawDataSignature[] withdraws;
        SettlementSignature[] settlements;
        AdlSignature[] adls;
        LiquidationSignature[] liquidations;
        FeeDistributionSignature[] feeDistributions;
        DelegeteSignerSignature[] delegateSigners;
    }

    function eventsUploadEncodeHash(EventTypes.EventUpload memory data) internal pure returns (bytes memory) {
        // counArray is used to count the number of each event type
        // countArray[0]: withdraws, countArray[1]: settlements, countArray[2]: adls, countArray[3]: liquidations, countArray[4]: feeDistributions, countArray[5]: delegateSigners, countArray[6]: delegateWithdraws
        // countArray2 is used to count the number of each filed signature structure inside EventUploadSignature, because the event withdraw and event delegateWith share the common  WithdrawDataSignature[],
        // so we have `withdraws: new WithdrawDataSignature[](countArray[0]+countArray[6])` when initializing eventUploadSignature
        uint8[] memory countArray = new uint8[](7);
        uint8[] memory countArray2 = new uint8[](7); // 0: withdraws + delegate, 1: settlements, 2: adls, 3: liquidations, 4: feeDistributions, 5: delegateSigners 6: null
        uint256 len = data.events.length;
        for (uint256 i = 0; i < len; i++) {
            countArray[data.events[i].bizType - 1]++;
        }
        EventUploadSignature memory eventUploadSignature = EventUploadSignature({
            batchId: data.batchId,
            withdraws: new WithdrawDataSignature[](countArray[0]+countArray[6]),
            settlements: new SettlementSignature[](countArray[1]),
            adls: new AdlSignature[](countArray[2]),
            liquidations: new LiquidationSignature[](countArray[3]),
            feeDistributions: new FeeDistributionSignature[](countArray[4]),
            delegateSigners: new DelegeteSignerSignature[](countArray[5])
        });

        for (uint256 i = 0; i < len; i++) {
            EventTypes.EventUploadData memory eventUploadData = data.events[i];
            if (eventUploadData.bizType == 1 || eventUploadData.bizType == 7) {
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
            } else if (eventUploadData.bizType == 5) {
                EventTypes.FeeDistribution memory feeDistribution =
                    abi.decode(eventUploadData.data, (EventTypes.FeeDistribution));
                FeeDistributionSignature memory feeDistributionSignature = FeeDistributionSignature({
                    eventId: eventUploadData.eventId,
                    fromAccountId: feeDistribution.fromAccountId,
                    toAccountId: feeDistribution.toAccountId,
                    amount: feeDistribution.amount,
                    tokenHash: feeDistribution.tokenHash
                });
                eventUploadSignature.feeDistributions[countArray2[4]] = feeDistributionSignature;
                countArray2[4]++;
            } else if (eventUploadData.bizType == 6) {
                EventTypes.DelegateSigner memory delegateSigner =
                    abi.decode(eventUploadData.data, (EventTypes.DelegateSigner));
                DelegeteSignerSignature memory delegeteSignerSignature = DelegeteSignerSignature({
                    eventId: eventUploadData.eventId,
                    delegateSigner: delegateSigner.delegateSigner,
                    delegateContract: delegateSigner.delegateContract,
                    brokerHash: delegateSigner.brokerHash,
                    chainId: delegateSigner.chainId
                });
                eventUploadSignature.delegateSigners[countArray2[5]] = delegeteSignerSignature;
                countArray2[5]++;
            }
        }
        bytes memory encoded;
        if (eventUploadSignature.delegateSigners.length > 0) {
            // v3 signature, only support [v2 delegateSigners]
            encoded = abi.encode(
                eventUploadSignature.batchId,
                eventUploadSignature.withdraws,
                eventUploadSignature.settlements,
                eventUploadSignature.adls,
                eventUploadSignature.liquidations,
                eventUploadSignature.feeDistributions,
                eventUploadSignature.delegateSigners
            );
        } else if (eventUploadSignature.feeDistributions.length > 0) {
            // v2 signature, only support [v1, feeDistributions]
            encoded = abi.encode(
                eventUploadSignature.batchId,
                eventUploadSignature.withdraws,
                eventUploadSignature.settlements,
                eventUploadSignature.adls,
                eventUploadSignature.liquidations,
                eventUploadSignature.feeDistributions
            );
        } else {
            // v1 signature, only support [withdraws(+delegateWithdraw), settlements, adls, liquidations]
            encoded = abi.encode(
                eventUploadSignature.batchId,
                eventUploadSignature.withdraws,
                eventUploadSignature.settlements,
                eventUploadSignature.adls,
                eventUploadSignature.liquidations
            );
        }
        return encoded;
    }

    function eventsUploadEncodeHashVerify(EventTypes.EventUpload memory data, address signer)
        internal
        pure
        returns (bool)
    {
        bytes32 h = ECDSA.toEthSignedMessageHash(keccak256(eventsUploadEncodeHash(data)));
        return verify(h, data.r, data.s, data.v, signer);
    }

    function marketUploadEncodeHashVerify(MarketTypes.UploadPerpPrice memory data, address signer)
        internal
        pure
        returns (bool)
    {
        bytes memory encoded = abi.encode(data.maxTimestamp, data.perpPrices);
        bytes32 h = ECDSA.toEthSignedMessageHash(keccak256(encoded));
        return verify(h, data.r, data.s, data.v, signer);
    }

    function marketUploadEncodeHashVerify(MarketTypes.UploadSumUnitaryFundings memory data, address signer)
        internal
        pure
        returns (bool)
    {
        bytes memory encoded = abi.encode(data.maxTimestamp, data.sumUnitaryFundings);
        bytes32 h = ECDSA.toEthSignedMessageHash(keccak256(encoded));
        return verify(h, data.r, data.s, data.v, signer);
    }

    function rebalanceBurnUploadEncodeHashVerify(RebalanceTypes.RebalanceBurnUploadData memory data, address signer)
        internal
        pure
        returns (bool)
    {
        bytes memory encoded =
            abi.encode(data.rebalanceId, data.amount, data.tokenHash, data.burnChainId, data.mintChainId);
        bytes32 h = ECDSA.toEthSignedMessageHash(keccak256(encoded));
        return verify(h, data.r, data.s, data.v, signer);
    }

    function rebalanceMintUploadEncodeHashVerify(RebalanceTypes.RebalanceMintUploadData memory data, address signer)
        internal
        pure
        returns (bool)
    {
        bytes memory encoded = abi.encode(
            data.rebalanceId,
            data.amount,
            data.tokenHash,
            data.burnChainId,
            data.mintChainId,
            data.messageBytes,
            data.messageSignature
        );
        bytes32 h = ECDSA.toEthSignedMessageHash(keccak256(encoded));
        return verify(h, data.r, data.s, data.v, signer);
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "./types/PerpTypes.sol";
import "./types/EventTypes.sol";
import "./types/MarketTypes.sol";
import "./types/RebalanceTypes.sol";
import "./Ed25519/Ed25519.sol";
import "./Bytes32ToAsciiBytes.sol";

/// @title Signature library
/// @author Orderly_Rubick, Orderly_Zion
library Signature {
    // keccak256("Orderly Network")
    bytes32 constant HASH_ORDERLY_NETWORK = hex"768a5991f3d52b299dee3ad82f4adaeaa9fb91ffcf7afbecbac40c39201773b4";

    /**
     * // 01 -> numRequiredSignatures
     * // 00 -> numReadonlySignedAccounts
     * // 02 -> numReadonlyUnsignedAccounts
     * // 03 -> accountAddressesLength
     * // 8d74357c58760282acca9f5af78bb51e2adaa44d6248bb9243116e9ad4a5b4a9 ->  AXBG9WUtfKn3c1hTsYB5UGxTAXjouunQUpdiQGnZwVyz feePayer, from input
     * // 0306466fe5211732ffecadba72c39be7bc8ce5bbc5f7126b2c439b3a40000000 -> ComputeBudget111111111111111111111111111111 ComputeBudget
     * // 054a535a992921064d24e87160da387c7c35b5ddbc92bb81e41fa8404105448d ->  MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr MemoProgramId
     * // 0000000000000000000000000000000000000000000000000000000000000000 -> blockHash
     *
     * // 03 -> instructionsLength
     * // 01 -> account index ComputeBudget111111111111111111111111111111
     * // 00 -> key number
     * // 09 -> data size
     * // 030000000000000000 setComputeUnitLimit
     *
     * // 01 -> account index ComputeBudget111111111111111111111111111111
     * // 00 -> key number
     * // 05 -> datasize
     * // 0200000000 -> setComputeUnitPrice
     * //
     * // 02 -> account index MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr
     * // 00 -> key number
     * // 40 -> message length
     * // 34643734316236663165623239636232613962393931316338326635366661386437336230343935396433643964323232383935646636633062323861613135 -> message, from input
     */
    function solanaLedgerSignature(bytes32 pubkey, bytes32 messageRaw) internal pure returns (bytes memory) {
        bytes memory message = Bytes32ToAsciiBytes.bytes32ToAsciiBytes(messageRaw);
        bytes memory m1 = hex"01000203";
        bytes memory m2 =
            hex"0306466fe5211732ffecadba72c39be7bc8ce5bbc5f7126b2c439b3a40000000054a535a992921064d24e87160da387c7c35b5ddbc92bb81e41fa8404105448d0000000000000000000000000000000000000000000000000000000000000000030100090300000000000000000100050200000000020040";
        bytes memory m = abi.encodePacked(m1, abi.encodePacked(pubkey), m2, message);
        return m;
    }

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

    function verifyWithdrawSol(EventTypes.WithdrawDataSol memory data) internal pure returns (bool) {
        bytes32 hashStruct = keccak256(
            abi.encode(
                keccak256(abi.encodePacked(data.brokerId)),
                keccak256(abi.encodePacked(data.tokenSymbol)),
                data.chainId,
                data.receiver,
                data.tokenAmount,
                data.withdrawNonce,
                data.timestamp,
                HASH_ORDERLY_NETWORK // salt
            )
        );
        bytes32 k = data.sender;
        bytes32 r = data.r;
        bytes32 s = data.s;
        bytes memory m = Bytes32ToAsciiBytes.bytes32ToAsciiBytes(hashStruct);
        // the former is the signature of message from eoa, the latter is the signature of tx from ledger
        return Ed25519.verify(k, r, s, m) || Ed25519.verify(k, r, s, solanaLedgerSignature(k, hashStruct));
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

    struct AdlV2Signature {
        uint64 eventId; // flat map to this
        bytes32 accountId;
        bytes32 symbolHash;
        int128 positionQtyTransfer;
        int128 costPositionTransfer;
        uint128 adlPrice;
        int128 sumUnitaryFundings;
        uint64 timestamp;
        bool isInsuranceAccount;
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

    struct LiquidationV2Signature {
        uint64 eventId; // flat map to this
        bytes32 accountId;
        bytes32 liquidatedAssetHash;
        int128 insuranceTransferAmount;
        uint64 timestamp;
        bool isInsuranceAccount;
        EventTypes.LiquidationTransferV2[] liquidationTransfers;
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

    struct WithdrawSolDataSignature {
        uint64 eventId; // flat map to this
        string brokerId;
        bytes32 accountId;
        uint256 chainId;
        bytes32 sender;
        bytes32 receiver;
        string token;
        uint128 tokenAmount;
        uint128 fee;
        uint64 withdrawNonce;
        uint64 timestamp;
    }

    struct Withdraw2ContractSignature {
        uint64 eventId; // flat map to this
        bytes32 brokerHash;
        bytes32 accountId;
        uint256 chainId;
        address sender;
        address receiver;
        bytes32 tokenHash;
        uint128 tokenAmount;
        uint128 fee;
        uint64 withdrawNonce;
        uint64 timestamp;
        EventTypes.VaultEnum vaultType;
        uint256 clientId;
    }

    struct EventUploadSignature {
        uint64 batchId;
        WithdrawDataSignature[] withdraws;
        SettlementSignature[] settlements;
        AdlSignature[] adls;
        LiquidationSignature[] liquidations;
        FeeDistributionSignature[] feeDistributions;
        DelegeteSignerSignature[] delegateSigners;
        AdlV2Signature[] adlV2s;
        LiquidationV2Signature[] liquidationV2s;
        WithdrawSolDataSignature[] withdrawSols;
        Withdraw2ContractSignature[] withdraw2Contracts;
    }

    function eventsUploadEncodeHash(EventTypes.EventUpload memory data) internal pure returns (bytes memory) {
        // counArray is used to count the number of each event type
        // countArray[0]: withdraws, countArray[1]: settlements, countArray[2]: adls, countArray[3]: liquidations, countArray[4]: feeDistributions, countArray[5]: delegateSigners, countArray[6]: delegateWithdraws
        // countArray2 is used to count the number of each filed signature structure inside EventUploadSignature, because the event withdraw and event delegateWith share the common  WithdrawDataSignature[],
        // so we have `withdraws: new WithdrawDataSignature[](countArray[0]+countArray[6])` when initializing eventUploadSignature
        // 0: withdraws + delegate, 1: settlements, 2: adls, 3: liquidations
        // 4: feeDistributions, 5: delegateSigners, 6: null, 7: adlV2s, 8: liquidationV2s
        // 9: withdrawSol, 10: withdraw2Contract
        uint8[] memory countArray = new uint8[](11);
        uint8[] memory countArray2 = new uint8[](11);
        uint256 len = data.events.length;
        for (uint256 i = 0; i < len; i++) {
            countArray[data.events[i].bizType - 1]++;
        }
        EventUploadSignature memory eventUploadSignature = EventUploadSignature({
            batchId: data.batchId,
            withdraws: new WithdrawDataSignature[](countArray[0] + countArray[6]),
            settlements: new SettlementSignature[](countArray[1]),
            adls: new AdlSignature[](countArray[2]),
            liquidations: new LiquidationSignature[](countArray[3]),
            feeDistributions: new FeeDistributionSignature[](countArray[4]),
            delegateSigners: new DelegeteSignerSignature[](countArray[5]),
            adlV2s: new AdlV2Signature[](countArray[7]),
            liquidationV2s: new LiquidationV2Signature[](countArray[8]),
            withdrawSols: new WithdrawSolDataSignature[](countArray[9]),
            withdraw2Contracts: new Withdraw2ContractSignature[](countArray[10])
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
            } else if (eventUploadData.bizType == 8) {
                EventTypes.AdlV2 memory adlV2 = abi.decode(eventUploadData.data, (EventTypes.AdlV2));
                AdlV2Signature memory adlV2Signature = AdlV2Signature({
                    eventId: eventUploadData.eventId,
                    accountId: adlV2.accountId,
                    symbolHash: adlV2.symbolHash,
                    positionQtyTransfer: adlV2.positionQtyTransfer,
                    costPositionTransfer: adlV2.costPositionTransfer,
                    adlPrice: adlV2.adlPrice,
                    sumUnitaryFundings: adlV2.sumUnitaryFundings,
                    timestamp: adlV2.timestamp,
                    isInsuranceAccount: adlV2.isInsuranceAccount
                });
                eventUploadSignature.adlV2s[countArray2[7]] = adlV2Signature;
                countArray2[7]++;
            } else if (eventUploadData.bizType == 9) {
                EventTypes.LiquidationV2 memory liquidationV2 =
                    abi.decode(eventUploadData.data, (EventTypes.LiquidationV2));
                LiquidationV2Signature memory liquidationV2Signature = LiquidationV2Signature({
                    eventId: eventUploadData.eventId,
                    accountId: liquidationV2.accountId,
                    liquidatedAssetHash: liquidationV2.liquidatedAssetHash,
                    insuranceTransferAmount: liquidationV2.insuranceTransferAmount,
                    timestamp: liquidationV2.timestamp,
                    isInsuranceAccount: liquidationV2.isInsuranceAccount,
                    liquidationTransfers: liquidationV2.liquidationTransfers
                });
                eventUploadSignature.liquidationV2s[countArray2[8]] = liquidationV2Signature;
                countArray2[8]++;
            } else if (eventUploadData.bizType == 10) {
                EventTypes.WithdrawDataSol memory withdrawSolData =
                    abi.decode(eventUploadData.data, (EventTypes.WithdrawDataSol));
                WithdrawSolDataSignature memory withdrawSolDataSignature = WithdrawSolDataSignature({
                    eventId: eventUploadData.eventId,
                    brokerId: withdrawSolData.brokerId,
                    accountId: withdrawSolData.accountId,
                    chainId: withdrawSolData.chainId,
                    sender: withdrawSolData.sender,
                    receiver: withdrawSolData.receiver,
                    token: withdrawSolData.tokenSymbol,
                    tokenAmount: withdrawSolData.tokenAmount,
                    fee: withdrawSolData.fee,
                    withdrawNonce: withdrawSolData.withdrawNonce,
                    timestamp: withdrawSolData.timestamp
                });
                eventUploadSignature.withdrawSols[countArray2[9]] = withdrawSolDataSignature;
                countArray2[9]++;
            } else if (eventUploadData.bizType == 11) {
                EventTypes.Withdraw2Contract memory withdraw2Contract =
                    abi.decode(eventUploadData.data, (EventTypes.Withdraw2Contract));
                Withdraw2ContractSignature memory withdraw2ContractSignature = Withdraw2ContractSignature({
                    eventId: eventUploadData.eventId,
                    brokerHash: withdraw2Contract.brokerHash,
                    accountId: withdraw2Contract.accountId,
                    chainId: withdraw2Contract.chainId,
                    sender: withdraw2Contract.sender,
                    receiver: withdraw2Contract.receiver,
                    tokenHash: withdraw2Contract.tokenHash,
                    tokenAmount: withdraw2Contract.tokenAmount,
                    fee: withdraw2Contract.fee,
                    withdrawNonce: withdraw2Contract.withdrawNonce,
                    timestamp: withdraw2Contract.timestamp,
                    vaultType: withdraw2Contract.vaultType,
                    clientId: withdraw2Contract.clientId
                });
                eventUploadSignature.withdraw2Contracts[countArray2[10]] = withdraw2ContractSignature;
                countArray2[10]++;
            } else {
                // should never happen
                revert("Invalid bizType");
            }
        }
        bytes memory encoded;
        if (eventUploadSignature.withdraw2Contracts.length > 0) {
            // v6 signature, only support [v5, withdraw2Contracts]
            encoded = abi.encode(
                eventUploadSignature.batchId,
                eventUploadSignature.withdraws,
                eventUploadSignature.settlements,
                eventUploadSignature.adls,
                eventUploadSignature.liquidations,
                eventUploadSignature.feeDistributions,
                eventUploadSignature.delegateSigners,
                eventUploadSignature.adlV2s,
                eventUploadSignature.liquidationV2s,
                eventUploadSignature.withdrawSols,
                eventUploadSignature.withdraw2Contracts
            );
        } else if (eventUploadSignature.withdrawSols.length > 0) {
            // v5 signature, only support [v4, withdrawSols]
            encoded = abi.encode(
                eventUploadSignature.batchId,
                eventUploadSignature.withdraws,
                eventUploadSignature.settlements,
                eventUploadSignature.adls,
                eventUploadSignature.liquidations,
                eventUploadSignature.feeDistributions,
                eventUploadSignature.delegateSigners,
                eventUploadSignature.adlV2s,
                eventUploadSignature.liquidationV2s,
                eventUploadSignature.withdrawSols
            );
        } else if (eventUploadSignature.adlV2s.length > 0 || eventUploadSignature.liquidationV2s.length > 0) {
            // v4 signature, only support [v3, adlV2s, liquidationV2s]
            encoded = abi.encode(
                eventUploadSignature.batchId,
                eventUploadSignature.withdraws,
                eventUploadSignature.settlements,
                eventUploadSignature.adls,
                eventUploadSignature.liquidations,
                eventUploadSignature.feeDistributions,
                eventUploadSignature.delegateSigners,
                eventUploadSignature.adlV2s,
                eventUploadSignature.liquidationV2s
            );
        } else if (eventUploadSignature.delegateSigners.length > 0) {
            // v3 signature, only support [v2, delegateSigners]
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

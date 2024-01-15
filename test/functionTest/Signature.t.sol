// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/library/Signature.sol";

contract SignatureTest is Test {
    address constant addr = 0x6a9961Ace9bF0C1B8B98ba11558A4125B1f5EA3f;

    // https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/299009164/Test+vector
    function test_perpUploadEncodeHash_1() public {
        PerpTypes.FuturesTradeUpload memory t1 = PerpTypes.FuturesTradeUpload({
            tradeId: 417733,
            matchId: 1681722208647262950,
            accountId: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed63,
            symbolHash: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed63,
            side: true,
            tradeQty: 500000000,
            notional: 55000000,
            executedPrice: 1100000000,
            fee: 5000,
            feeAssetHash: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed63,
            sumUnitaryFundings: 1000000000000000,
            timestamp: 1681693408647
        });

        PerpTypes.FuturesTradeUpload[] memory trades = new PerpTypes.FuturesTradeUpload[](1);
        trades[0] = t1;

        bool succ = Signature.perpUploadEncodeHashVerify(
            PerpTypes.FuturesTradeUploadData({
                batchId: 18,
                count: 4,
                trades: trades,
                r: 0x543e72ea14c90ae0422bc5dcc4057b44b1f177780b843651e0d0da504384f4ab,
                s: 0x6ad60c31a85437e0cf2ff7c5a0ca9a18a0474d7e3d936cbf0e999dd897dea09d,
                v: 0x1b
            }),
            addr
        );
        assertEq(succ, true);
    }

    // https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/299009164/Test+vector
    function test_perpUploadEncodeHash_2() public {
        PerpTypes.FuturesTradeUpload memory t1 = PerpTypes.FuturesTradeUpload({
            tradeId: 417733,
            matchId: 1681722208647262950,
            accountId: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed63,
            symbolHash: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed63,
            side: true,
            tradeQty: 500000000,
            notional: 55000000,
            executedPrice: 1100000000,
            fee: 5000,
            feeAssetHash: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed63,
            sumUnitaryFundings: 1000000000000000,
            timestamp: 1681693408647
        });
        PerpTypes.FuturesTradeUpload memory t2 = PerpTypes.FuturesTradeUpload({
            tradeId: 417734,
            matchId: 1681722208647262951,
            accountId: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed64,
            symbolHash: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed65,
            side: false,
            tradeQty: 500000001,
            notional: 55000001,
            executedPrice: 1100000001,
            fee: 5001,
            feeAssetHash: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed66,
            sumUnitaryFundings: 1000000000000001,
            timestamp: 1681693408648
        });
        PerpTypes.FuturesTradeUpload[] memory trades = new PerpTypes.FuturesTradeUpload[](2);
        trades[0] = t1;
        trades[1] = t2;

        bool succ = Signature.perpUploadEncodeHashVerify(
            PerpTypes.FuturesTradeUploadData({
                batchId: 18,
                count: 4,
                trades: trades,
                r: 0xcc91371a8c28fc72544a468691bfbb810487d6c448241a1d4b4889b6c0de2d5b,
                s: 0x7a053f078e0f1e791348fa5163dd8d1cc107cea19b47c9e87581cc4af85e0a74,
                v: 0x1c
            }),
            addr
        );

        assertEq(succ, true);
    }

    // https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/299009164/Test+vector#%E6%95%B0%E6%8D%AE1.1
    function test_eventUploadEncodeHash_1() public {
        EventTypes.WithdrawData memory w1 = EventTypes.WithdrawData({
            tokenAmount: 123,
            fee: 5000,
            chainId: 10086,
            accountId: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed63,
            r: 0x0,
            s: 0x0,
            v: 0x0,
            sender: 0x6a9961Ace9bF0C1B8B98ba11558A4125B1f5EA3f,
            withdrawNonce: 9,
            receiver: 0x6a9961Ace9bF0C1B8B98ba11558A4125B1f5EA3f,
            timestamp: 1683270380530,
            brokerId: "woo_dex",
            tokenSymbol: "USDC"
        });

        EventTypes.Adl memory a1 = EventTypes.Adl({
            accountId: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed64,
            insuranceAccountId: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed65,
            symbolHash: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed66,
            positionQtyTransfer: 2000000000,
            costPositionTransfer: 44000000,
            adlPrice: 220000000,
            sumUnitaryFundings: 12340000000,
            timestamp: 1683270380531
        });
        EventTypes.EventUploadData[] memory events = new EventTypes.EventUploadData[](2);
        events[0] = EventTypes.EventUploadData({bizType: 1, eventId: 1, data: abi.encode(w1)});
        events[1] = EventTypes.EventUploadData({bizType: 3, eventId: 3, data: abi.encode(a1)});
        EventTypes.EventUpload memory e1 = EventTypes.EventUpload({
            events: events,
            r: 0x0a29a4bd74c2f0d6e20f68ae5361483015b9ff35b650aeb2da3aa9229e19999b,
            s: 0x2becba8febb53c1d7c582871a5fb54103b224828f3b8c56dddb0bef57fcb818e,
            v: 0x1b,
            count: 4,
            batchId: 18
        });

        bool succ = Signature.eventsUploadEncodeHashVerify(e1, addr);
        assertEq(succ, true);
    }

    // https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/299009164/Test+vector#%E6%95%B0%E6%8D%AE2.1
    function test_eventUploadEncodeHash_2() public {
        EventTypes.WithdrawData memory w1 = EventTypes.WithdrawData({
            tokenAmount: 123,
            fee: 5000,
            chainId: 10086,
            accountId: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed63,
            r: 0x0,
            s: 0x0,
            v: 0x0,
            sender: 0x6a9961Ace9bF0C1B8B98ba11558A4125B1f5EA3f,
            withdrawNonce: 9,
            receiver: 0x6a9961Ace9bF0C1B8B98ba11558A4125B1f5EA3f,
            timestamp: 1683270380530,
            brokerId: "woo_dex",
            tokenSymbol: "USDC"
        });

        EventTypes.Adl memory a1 = EventTypes.Adl({
            accountId: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed64,
            insuranceAccountId: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed65,
            symbolHash: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed66,
            positionQtyTransfer: 2000000000,
            costPositionTransfer: 44000000,
            adlPrice: 220000000,
            sumUnitaryFundings: 12340000000,
            timestamp: 1683270380531
        });

        EventTypes.WithdrawData memory w2 = EventTypes.WithdrawData({
            tokenAmount: 12356,
            fee: 5001,
            chainId: 10087,
            accountId: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed64,
            r: 0x0,
            s: 0x0,
            v: 0x0,
            sender: 0x6a9961Ace9bF0C1B8B98ba11558A4125B1f5EA3f,
            withdrawNonce: 10,
            receiver: 0x6a9961Ace9bF0C1B8B98ba11558A4125B1f5EA3f,
            timestamp: 1683270380531,
            brokerId: "woofi_dex",
            tokenSymbol: "USDC"
        });
        EventTypes.EventUploadData[] memory events = new EventTypes.EventUploadData[](3);
        events[0] = EventTypes.EventUploadData({bizType: 1, eventId: 1, data: abi.encode(w1)});
        events[1] = EventTypes.EventUploadData({bizType: 3, eventId: 3, data: abi.encode(a1)});
        events[2] = EventTypes.EventUploadData({bizType: 1, eventId: 4, data: abi.encode(w2)});
        EventTypes.EventUpload memory e1 = EventTypes.EventUpload({
            events: events,
            r: 0xfd3ee24f871ae1c8a16aa336b81558f9cc42d2b7891eea8ba1403b1224286419,
            s: 0x1aa444dac958a78d7f6a5fe07909118ef2882203a339e37c8bc138f61566449e,
            v: 0x1c,
            count: 4,
            batchId: 18
        });

        bool succ = Signature.eventsUploadEncodeHashVerify(e1, addr);
        assertEq(succ, true);
    }

    // https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/299009164/Test+vector#%E6%95%B0%E6%8D%AE3
    function test_eventUploadEncodeHash_3() public {
        EventTypes.SettlementExecution[] memory se = new EventTypes.SettlementExecution[](1);
        se[0] = EventTypes.SettlementExecution({
            symbolHash: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed70,
            markPrice: 212000000,
            sumUnitaryFundings: 1230000000000,
            settledAmount: 101000000
        });
        EventTypes.Settlement memory s1 = EventTypes.Settlement({
            accountId: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed67,
            settledAmount: 101000000,
            settledAssetHash: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed68,
            insuranceAccountId: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed69,
            insuranceTransferAmount: 55000000,
            settlementExecutions: se,
            timestamp: 1683270380555
        });

        EventTypes.EventUploadData[] memory events = new EventTypes.EventUploadData[](1);
        events[0] = EventTypes.EventUploadData({bizType: 2, eventId: 7, data: abi.encode(s1)});
        EventTypes.EventUpload memory e1 = EventTypes.EventUpload({
            events: events,
            r: 0x63ac7591ee23fbdd865a010cd58c8e4fc76e8b25f1efb9afcd5936366898df38,
            s: 0x6d9a0cbe7b8b0dca6fa6d7af1f47b295a05571d0fbbaddff883fa7c70bec15ae,
            v: 0x1c,
            count: 4,
            batchId: 18
        });

        bool succ = Signature.eventsUploadEncodeHashVerify(e1, addr);
        assertEq(succ, true);
    }

    // https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/299009164/Test+vector#%E6%95%B0%E6%8D%AE4
    function test_eventUploadEncodeHash_4() public {
        EventTypes.WithdrawData memory w1 = EventTypes.WithdrawData({
            tokenAmount: 123,
            fee: 5000,
            chainId: 10086,
            accountId: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed63,
            r: 0x0,
            s: 0x0,
            v: 0x0,
            sender: 0x6a9961Ace9bF0C1B8B98ba11558A4125B1f5EA3f,
            withdrawNonce: 9,
            receiver: 0x6a9961Ace9bF0C1B8B98ba11558A4125B1f5EA3f,
            timestamp: 1683270380530,
            brokerId: "woo_dex",
            tokenSymbol: "USDC"
        });

        EventTypes.Adl memory a1 = EventTypes.Adl({
            accountId: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed64,
            insuranceAccountId: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed65,
            symbolHash: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed66,
            positionQtyTransfer: 2000000000,
            costPositionTransfer: 44000000,
            adlPrice: 220000000,
            sumUnitaryFundings: 12340000000,
            timestamp: 1683270380531
        });

        EventTypes.WithdrawData memory w2 = EventTypes.WithdrawData({
            tokenAmount: 12356,
            fee: 5001,
            chainId: 10087,
            accountId: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed64,
            r: 0x0,
            s: 0x0,
            v: 0x0,
            sender: 0x6a9961Ace9bF0C1B8B98ba11558A4125B1f5EA3f,
            withdrawNonce: 10,
            receiver: 0x6a9961Ace9bF0C1B8B98ba11558A4125B1f5EA3f,
            timestamp: 1683270380531,
            brokerId: "woofi_dex",
            tokenSymbol: "USDC"
        });

        EventTypes.SettlementExecution[] memory se = new EventTypes.SettlementExecution[](2);
        se[0] = EventTypes.SettlementExecution({
            symbolHash: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed70,
            markPrice: 212000000,
            sumUnitaryFundings: 1230000000000,
            settledAmount: 101000000
        });
        se[1] = EventTypes.SettlementExecution({
            symbolHash: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed71,
            markPrice: 212000001,
            sumUnitaryFundings: 1230000000001,
            settledAmount: 101000001
        });
        EventTypes.Settlement memory s1 = EventTypes.Settlement({
            accountId: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed67,
            settledAmount: 101000000,
            settledAssetHash: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed68,
            insuranceAccountId: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed69,
            insuranceTransferAmount: 55000000,
            settlementExecutions: se,
            timestamp: 1683270380555
        });

        EventTypes.LiquidationTransfer[] memory lt = new EventTypes.LiquidationTransfer[](1);
        lt[0] = EventTypes.LiquidationTransfer({
            liquidationTransferId: 2023,
            liquidatorAccountId: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed75,
            symbolHash: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed76,
            positionQtyTransfer: 2000000000,
            costPositionTransfer: 44000000,
            liquidatorFee: 200000,
            insuranceFee: 400000,
            liquidationFee: 600000,
            markPrice: 212000000,
            sumUnitaryFundings: 1230000000000
        });
        EventTypes.Liquidation memory l1 = EventTypes.Liquidation({
            liquidatedAccountId: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed72,
            insuranceAccountId: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed73,
            insuranceTransferAmount: 10000001,
            liquidatedAssetHash: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed74,
            liquidationTransfers: lt,
            timestamp: 1683270380556
        });

        EventTypes.Settlement memory s2 = EventTypes.Settlement({
            accountId: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed77,
            settledAmount: 101000002,
            settledAssetHash: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed78,
            insuranceAccountId: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed79,
            insuranceTransferAmount: 55000002,
            settlementExecutions: new EventTypes.SettlementExecution[](0),
            timestamp: 1683270380558
        });

        EventTypes.EventUploadData[] memory events = new EventTypes.EventUploadData[](6);
        events[0] = EventTypes.EventUploadData({bizType: 1, eventId: 1, data: abi.encode(w1)});
        events[1] = EventTypes.EventUploadData({bizType: 3, eventId: 3, data: abi.encode(a1)});
        events[2] = EventTypes.EventUploadData({bizType: 1, eventId: 4, data: abi.encode(w2)});
        events[3] = EventTypes.EventUploadData({bizType: 2, eventId: 7, data: abi.encode(s1)});
        events[4] = EventTypes.EventUploadData({bizType: 4, eventId: 9, data: abi.encode(l1)});
        events[5] = EventTypes.EventUploadData({bizType: 2, eventId: 11, data: abi.encode(s2)});
        EventTypes.EventUpload memory e1 = EventTypes.EventUpload({
            events: events,
            r: 0xe6efcb099fcc9ebef50514c153f666e3e2c2087c723fa3ec6c767cddaa5ec3f4,
            s: 0x7bee154827afce72d3bf6882e028adc319ca20977291da79c331d4474858f0e1,
            v: 0x1c,
            count: 4,
            batchId: 18
        });

        bool succ = Signature.eventsUploadEncodeHashVerify(e1, addr);
        assertEq(succ, true);
    }

    // https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/288358489/Operator+Test+cases
    function test_eventUploadEncodeHash_extra_1() public {
        EventTypes.WithdrawData memory w1 = EventTypes.WithdrawData({
            tokenAmount: 1000000,
            fee: 0,
            chainId: 43113,
            accountId: 0xb336b4dc9f87302da656862ca142a8d454268ae61759bf25d986f863d8374cf1,
            r: 0x4a88398c91b3eb572e2f889882bf060764853e71f81b7edb1e7155c39e734b21,
            s: 0x03f06b07855e5824bf2bea53d960469d40477a2d5fa007c4d70d8f2426270d0d,
            v: 0x1b,
            sender: 0xb2EEefB3D6922C4270d174A4020d71D8Bd23C229,
            withdrawNonce: 9,
            receiver: 0xb2EEefB3D6922C4270d174A4020d71D8Bd23C229,
            timestamp: 1689044649193,
            brokerId: "woofi_dex",
            tokenSymbol: "USDC"
        });
        EventTypes.EventUploadData[] memory events = new EventTypes.EventUploadData[](1);
        events[0] = EventTypes.EventUploadData({bizType: 1, eventId: 230711030400003, data: abi.encode(w1)});
        EventTypes.EventUpload memory e1 = EventTypes.EventUpload({
            events: events,
            r: 0x651929c1b2bfae1904e3a5398fd6ae9f0cd148d51d179ebbe88fab2249522648,
            s: 0x38d8776b1a0d21a897fe5a5dab317bb76f90d4fb6429cf3d6387b5725850c0ab,
            v: 0x1c,
            count: 1,
            batchId: 1
        });

        bool succ = Signature.eventsUploadEncodeHashVerify(e1, addr);
        assertEq(succ, true);
    }

    // https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/299009164/Test+vector#%E6%95%B0%E6%8D%AE1.2
    function test_marketCfgUploadEncodeHash_1() public {
        MarketTypes.PerpPrice[] memory perpPrices = new MarketTypes.PerpPrice[](2);
        perpPrices[0] = MarketTypes.PerpPrice({
            indexPrice: 100000777,
            markPrice: 100000888,
            symbolHash: 0x7e83089239db756ee233fa8972addfea16ae653db0f692e4851aed546b21caeb,
            timestamp: 1580794149123
        });
        perpPrices[1] = MarketTypes.PerpPrice({
            indexPrice: 100000123,
            markPrice: 100000456,
            symbolHash: 0x5a8133e52befca724670dbf2cade550c522c2410dd5b1189df675e99388f509d,
            timestamp: 1580794149789
        });
        MarketTypes.UploadPerpPrice memory data = MarketTypes.UploadPerpPrice({
            r: 0x641756217ae53e90d718b1c25222939cf081fc36156c6638bad9758b640f1207,
            s: 0x4df04d08e92e39bf0042f775da00456472f6932b02b79f11c80c4f19d2c37f70,
            v: 0x1c,
            maxTimestamp: 1580794149789,
            perpPrices: perpPrices
        });
        bool succ = Signature.marketUploadEncodeHashVerify(data, addr);
        assertEq(succ, true);
    }

    // https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/299009164/Test+vector#%E6%95%B0%E6%8D%AE2.2
    function test_marketCfgUploadEncodeHash_2() public {
        MarketTypes.SumUnitaryFunding[] memory sumUnitaryFundings = new MarketTypes.SumUnitaryFunding[](2);
        sumUnitaryFundings[0] = MarketTypes.SumUnitaryFunding({
            sumUnitaryFunding: 101200888,
            symbolHash: 0x7e83089239db756ee233fa8972addfea16ae653db0f692e4851aed546b21caeb,
            timestamp: 1581794149123
        });
        sumUnitaryFundings[1] = MarketTypes.SumUnitaryFunding({
            sumUnitaryFunding: 104400456,
            symbolHash: 0x5a8133e52befca724670dbf2cade550c522c2410dd5b1189df675e99388f509d,
            timestamp: 1580794149789
        });
        MarketTypes.UploadSumUnitaryFundings memory data = MarketTypes.UploadSumUnitaryFundings({
            r: 0xadacfb14ee22deb3fd8dd8e03fb21279ffd2e7cfc580bde4905af635c96b762a,
            s: 0x49d02133737500776481766c5639b7abd2a56bbcbe37329fa5dd37e1f743a908,
            v: 0x1b,
            maxTimestamp: 1580794149789,
            sumUnitaryFundings: sumUnitaryFundings
        });
        bool succ = Signature.marketUploadEncodeHashVerify(data, addr);
        assertEq(succ, true);
    }

    // https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/299009164/Test+vector#settlement
    function test_eventUploadEncodeHash_extra_2() public {
        EventTypes.SettlementExecution[] memory se = new EventTypes.SettlementExecution[](1);
        se[0] = EventTypes.SettlementExecution({
            symbolHash: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed70,
            markPrice: 212000000,
            sumUnitaryFundings: 1230000000000,
            settledAmount: 101000000
        });
        EventTypes.Settlement memory s1 = EventTypes.Settlement({
            accountId: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed67,
            settledAmount: 101000000,
            settledAssetHash: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed68,
            insuranceAccountId: 0x0000000000000000000000000000000000000000000000000000000000000000,
            insuranceTransferAmount: 0,
            settlementExecutions: se,
            timestamp: 1683270380555
        });

        EventTypes.EventUploadData[] memory events = new EventTypes.EventUploadData[](1);
        events[0] = EventTypes.EventUploadData({bizType: 2, eventId: 7, data: abi.encode(s1)});
        EventTypes.EventUpload memory e1 = EventTypes.EventUpload({
            events: events,
            r: 0xd6248d44b4f0750cb9c46b615c1c58959d815288ecd2c7a0c43bf02f5f9ef1d0,
            s: 0x1d68800fb0743f1355f32f6eefb86fc599af4c949ab45c585913de37af4658ac,
            v: 0x1c,
            count: 4,
            batchId: 18
        });

        bool succ = Signature.eventsUploadEncodeHashVerify(e1, addr);
        assertEq(succ, true);
    }

    // https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/445056152/FeeDisutrubution+Event+Upload
    function test_eventUploadEncodeHash_feeDistribution() public {
        EventTypes.FeeDistribution memory fee0 = EventTypes.FeeDistribution({
            fromAccountId: 0x9ff99a5d6cb71a3ef897b0fff5f5801af6dc5f72d8f1608e61409b8fc965bd68,
            toAccountId: 0xc69f41c55c00e4d875b3e82eeb0fcda3de2090a10130baf3c1ffee0f2e7ce243,
            amount: 1231245125,
            tokenHash: 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa
        });
        EventTypes.FeeDistribution memory fee1 = EventTypes.FeeDistribution({
            fromAccountId: 0xc69f41c55c00e4d875b3e82eeb0fcda3de2090a10130baf3c1ffee0f2e7ce243,
            toAccountId: 0x9ff99a5d6cb71a3ef897b0fff5f5801af6dc5f72d8f1608e61409b8fc965bd68,
            amount: 6435342234,
            tokenHash: 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa
        });

        EventTypes.EventUploadData[] memory events = new EventTypes.EventUploadData[](2);
        events[0] = EventTypes.EventUploadData({bizType: 5, eventId: 1274, data: abi.encode(fee0)});
        events[1] = EventTypes.EventUploadData({bizType: 5, eventId: 1277, data: abi.encode(fee1)});
        EventTypes.EventUpload memory e1 = EventTypes.EventUpload({
            events: events,
            r: 0x26eb59ba41e0a9e1c729c8d9f7e766ee4213886e13dfa6d985151180ff3af41f,
            s: 0x798c57e7dbf574c52a5583299c460ba70ef19482bec4c8fa2edbdaf01ab2fa95,
            v: 0x1c,
            count: 2,
            batchId: 7888
        });

        bool succ = Signature.eventsUploadEncodeHashVerify(e1, addr);
        assertEq(succ, true);
    }

    // https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/401440769/Rebalance+Test+vector#Burn
    function test_rebalanceBurnUploadEncodeHash() public {
        RebalanceTypes.RebalanceBurnUploadData memory data = RebalanceTypes.RebalanceBurnUploadData({
            r: 0x80e4cf10349a922a52efb8764cd07a107dc9a68865fd2a5e4ee539199b60f217,
            s: 0x44035df25557de70ebbf18d600052995a925096ea7e6bd217262e965f33e5565,
            v: 0x1c,
            rebalanceId: 123,
            amount: 1234567,
            tokenHash: 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa,
            burnChainId: 43113,
            mintChainId: 421613
        });
        bool succ = Signature.rebalanceBurnUploadEncodeHashVerify(data, addr);
        assertEq(succ, true);
    }

    // https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/401440769/Rebalance+Test+vector#Mint
    function test_rebalanceMintUploadEncodeHash() public {
        RebalanceTypes.RebalanceMintUploadData memory data = RebalanceTypes.RebalanceMintUploadData({
            r: 0xc9dc61f67d71ffcfebacf463026957c466e452c0d1e292bfde8eadf221f3e78b,
            s: 0x07363a680273ecf7030c8a869d23c82b5564463bb37b9340921c8b4bdc03924f,
            v: 0x1b,
            rebalanceId: 123,
            amount: 1234567,
            tokenHash: 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa,
            burnChainId: 43113,
            mintChainId: 421613,
            messageBytes: abi.encodePacked(
                hex"000000000000000300000000000000000000033800000000000000000000000012dcfd3fe2e9eac2859fd1ed86d2ab8c5a2f9352000000000000000000000000d0c3da58f55358142b8d3e06c1c30c5c6114efe8000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000fd064a18f3bf249cf1f87fc203e90d8f650f2d63000000000000000000000000dd3287043493e0a08d2b348397554096728b459c00000000000000000000000000000000000000000000000000000000004c4b40000000000000000000000000dd3287043493e0a08d2b348397554096728b459c"
                ),
            messageSignature: abi.encodePacked(
                hex"b8ccbb12d7cda9ca09dabf2440b18e731475ec613689fb3ac4469d09eeef18fe0bf53b8818780a643dc9e191de321504139a748df7ea037b51094fa0a6dadda91ba8b856e7d1af15c56af225a3bc442c6f46f48ac17d46a30711027d3019f4a40e3d55a507fdf11a4265031940ff54f6971139de1622827c5fee33e4ee82d7f07d1b"
                )
        });
        bool succ = Signature.rebalanceMintUploadEncodeHashVerify(data, addr);
        assertEq(succ, true);
    }
}

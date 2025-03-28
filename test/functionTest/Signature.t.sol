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
            storkPrice: 100000999,
            symbolHash: 0x7e83089239db756ee233fa8972addfea16ae653db0f692e4851aed546b21caeb,
            timestamp: 1580794149123
        });
        perpPrices[1] = MarketTypes.PerpPrice({
            indexPrice: 100000123,
            markPrice: 100000456,
            storkPrice: 100000789,
            symbolHash: 0x5a8133e52befca724670dbf2cade550c522c2410dd5b1189df675e99388f509d,
            timestamp: 1580794149789
        });
        MarketTypes.UploadPerpPrice memory data = MarketTypes.UploadPerpPrice({
            r: 0xf4538cfff871a94c4dd839c8405c591046fde29ea6fab639f2bed0e196abdbd1,
            s: 0x54a5af1302d848c79b9d178fcd80602651dae88b2af39787aee7b777f7542847,
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

    // https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/459277365/DelegateSigner+event+upload
    function test_eventUploadEncodeHash_delegateSigner() public {
        EventTypes.DelegateSigner memory delegateSigner0 = EventTypes.DelegateSigner({
            delegateSigner: 0xa3255bb283A607803791ba8A202262f4AB28b0B2,
            delegateContract: 0xa757D29D25116a657F2929DE61BCcA6173f731fE,
            brokerHash: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed66,
            chainId: 42161
        });

        EventTypes.DelegateSigner memory delegateSigner1 = EventTypes.DelegateSigner({
            delegateSigner: 0xa3255bb283A607803791ba8A202262f4AB28b0B2,
            delegateContract: 0xa757D29D25116a657F2929DE61BCcA6173f731fE,
            brokerHash: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed66,
            chainId: 42162
        });

        EventTypes.EventUploadData[] memory events = new EventTypes.EventUploadData[](2);
        events[0] = EventTypes.EventUploadData({bizType: 6, eventId: 234, data: abi.encode(delegateSigner0)});
        events[1] = EventTypes.EventUploadData({bizType: 6, eventId: 235, data: abi.encode(delegateSigner1)});
        EventTypes.EventUpload memory e1 = EventTypes.EventUpload({
            events: events,
            r: 0x485d4bda8c7ea56f553e486cbf311ab0575a257fa431b72c141a208fbed4eaca,
            s: 0x683916616409b086f102e1b58c08bc324e3bf17ebdefc6389813f67f934f5554,
            v: 0x1b,
            count: 2,
            batchId: 7888
        });

        bool succ = Signature.eventsUploadEncodeHashVerify(e1, addr);
        assertEq(succ, true);
    }

    // based on real data uploaded to OperatorManager contract
    function test_eventUploadEncodeHash_delegateSigner1() public {
        EventTypes.DelegateSigner memory delegateSigner0 = EventTypes.DelegateSigner({
            delegateSigner: 0xDd3287043493E0a08d2B348397554096728B459c,
            delegateContract: 0x65E6b31cC38aC83E0f11ACc67eaE5f7EFd31aB18,
            brokerHash: 0x6ca2f644ef7bd6d75953318c7f2580014941e753b3c6d54da56b3bf75dd14dfc,
            chainId: 11155420
        });

        EventTypes.DelegateSigner memory delegateSigner1 = EventTypes.DelegateSigner({
            delegateSigner: 0xDd3287043493E0a08d2B348397554096728B459c,
            delegateContract: 0x31c30d825a8A98C67C1c92b86e652f877435970b,
            brokerHash: 0x6ca2f644ef7bd6d75953318c7f2580014941e753b3c6d54da56b3bf75dd14dfc,
            chainId: 421614
        });

        EventTypes.DelegateSigner memory delegateSigner2 = EventTypes.DelegateSigner({
            delegateSigner: 0x2bAC7A6771613440989432c9B3B9a45dDd15e657,
            delegateContract: 0xa4394b62261061C629800C6D86D153A9F38f0cbB,
            brokerHash: 0x6ca2f644ef7bd6d75953318c7f2580014941e753b3c6d54da56b3bf75dd14dfc,
            chainId: 421614
        });

        EventTypes.DelegateSigner memory delegateSigner3 = EventTypes.DelegateSigner({
            delegateSigner: 0x2bAC7A6771613440989432c9B3B9a45dDd15e657,
            delegateContract: 0xa4394b62261061C629800C6D86D153A9F38f0cbB,
            brokerHash: 0x083098c593f395bea1de45dda552d9f14e8fcb0be3faaa7a1903c5477d7ba7fd,
            chainId: 421614
        });

        EventTypes.EventUploadData[] memory events = new EventTypes.EventUploadData[](4);
        events[0] = EventTypes.EventUploadData({bizType: 6, eventId: 1439, data: abi.encode(delegateSigner0)});
        events[1] = EventTypes.EventUploadData({bizType: 6, eventId: 1440, data: abi.encode(delegateSigner1)});
        events[2] = EventTypes.EventUploadData({bizType: 6, eventId: 1441, data: abi.encode(delegateSigner2)});
        events[3] = EventTypes.EventUploadData({bizType: 6, eventId: 1442, data: abi.encode(delegateSigner3)});
        EventTypes.EventUpload memory e1 = EventTypes.EventUpload({
            events: events,
            r: 0x12e4dfd5d7b7730b23a20461ac0585d8bae27b3efdd5bcaef0db1c7fe314f344,
            s: 0x29e11bebc46a5ae183616f88a8b8278bb83f5927a66dd0bb390ab8ec46be2a54,
            v: 0x1b,
            count: 4,
            batchId: 882
        });
        bool succ = Signature.eventsUploadEncodeHashVerify(e1, 0xDdDd1555A17d3Dad86748B883d2C1ce633A7cd88);
        assertEq(succ, true);
    }

    // https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/459277365/DelegateSigner+event+upload
    function test_eventUploadEncodeHash_delegateWitdraw() public {
        EventTypes.WithdrawData memory withdraw0 = EventTypes.WithdrawData({
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

        EventTypes.WithdrawData memory delegateWithdraw0 = EventTypes.WithdrawData({
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

        EventTypes.DelegateSigner memory delegateSigner0 = EventTypes.DelegateSigner({
            delegateSigner: 0xa3255bb283A607803791ba8A202262f4AB28b0B2,
            delegateContract: 0xa757D29D25116a657F2929DE61BCcA6173f731fE,
            brokerHash: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed66,
            chainId: 42162
        });

        EventTypes.FeeDistribution memory fee0 = EventTypes.FeeDistribution({
            fromAccountId: 0xc69f41c55c00e4d875b3e82eeb0fcda3de2090a10130baf3c1ffee0f2e7ce243,
            toAccountId: 0x9ff99a5d6cb71a3ef897b0fff5f5801af6dc5f72d8f1608e61409b8fc965bd68,
            amount: 6435342234,
            tokenHash: 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa
        });

        EventTypes.EventUploadData[] memory events = new EventTypes.EventUploadData[](4);

        events[0] = EventTypes.EventUploadData({bizType: 1, eventId: 1, data: abi.encode(withdraw0)});
        events[1] = EventTypes.EventUploadData({bizType: 7, eventId: 4, data: abi.encode(delegateWithdraw0)});
        events[2] = EventTypes.EventUploadData({bizType: 6, eventId: 235, data: abi.encode(delegateSigner0)});
        events[3] = EventTypes.EventUploadData({bizType: 5, eventId: 1277, data: abi.encode(fee0)});

        EventTypes.EventUpload memory e1 = EventTypes.EventUpload({
            events: events,
            r: 0x1843d7a15a61c3f6d9b23f322af959ec7c399d4db2acb6d38880abe37e256688,
            s: 0x7aee366da8bf51c9a2f5312f64c660fc34c88db19d72203624a1ea27d1c75ac6,
            v: 0x1b,
            count: 4,
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

    // https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/592216065/Signature+UT
    function test_eventUploadEncodeHash_adlV2() public {
        EventTypes.AdlV2 memory a1 = EventTypes.AdlV2({
            accountId: 0x9e4337fd086c18f6ce84c0da27101b26754a9ea7be95ec96645b987f04bcc2b2,
            symbolHash: 0xb5ec44c9e46c5ae2fa0473eb8c466c97ec83dd5f4eddf66f31e83b512cff503c,
            positionQtyTransfer: -10000000,
            costPositionTransfer: -1070650,
            adlPrice: 1070650000,
            sumUnitaryFundings: -97240000000000,
            timestamp: 1714080967339,
            isInsuranceAccount: false
        });
        EventTypes.AdlV2 memory a2 = EventTypes.AdlV2({
            accountId: 0x3ddab80a29e873d689134a4550573672eff87aaf91d3533b5bc8f2d350a38b15,
            symbolHash: 0xb5ec44c9e46c5ae2fa0473eb8c466c97ec83dd5f4eddf66f31e83b512cff503c,
            positionQtyTransfer: 10000000,
            costPositionTransfer: 1070650,
            adlPrice: 1070650000,
            sumUnitaryFundings: -97240000000000,
            timestamp: 1714080967339,
            isInsuranceAccount: true
        });
        EventTypes.EventUploadData[] memory events = new EventTypes.EventUploadData[](2);
        events[0] = EventTypes.EventUploadData({bizType: 8, eventId: 2, data: abi.encode(a1)});
        events[1] = EventTypes.EventUploadData({bizType: 8, eventId: 3, data: abi.encode(a2)});
        EventTypes.EventUpload memory e1 = EventTypes.EventUpload({
            events: events,
            r: 0x114bdef0a63cd924c56ebe7e865cafaffbcb89c6c01f664f3ce81832280282fb,
            s: 0x057f7c7919a60e0c8fb7f45fee8b59923f12fda3cc9baa1c70ff2a2568254729,
            v: 0x1b,
            count: 2,
            batchId: 7888
        });

        bool succ = Signature.eventsUploadEncodeHashVerify(e1, addr);
        assertEq(succ, true);
    }

    // https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/592216065/Signature+UT
    function test_eventUploadEncodeHash_liquidationV2() public {
        EventTypes.LiquidationTransferV2[] memory lt1 = new EventTypes.LiquidationTransferV2[](1);
        lt1[0] = EventTypes.LiquidationTransferV2({
            symbolHash: 0x2f1991e99a4e22a9e95ff1b67aee336b4047dc47612e36674fa23eb8c6017f2e,
            positionQtyTransfer: 254000000,
            costPositionTransfer: 402465540,
            fee: 14086294,
            markPrice: 15845100000,
            sumUnitaryFundings: 40376000000000000
        });
        EventTypes.LiquidationV2 memory l1 = EventTypes.LiquidationV2({
            accountId: 0x1975f1115c58292ef321f4055e122b47e60605f4a7ce6491b33afa91060db353,
            liquidatedAssetHash: 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa,
            insuranceTransferAmount: 0,
            timestamp: 1715043413487,
            isInsuranceAccount: false,
            liquidationTransfers: lt1
        });
        EventTypes.LiquidationTransferV2[] memory lt2 = new EventTypes.LiquidationTransferV2[](1);
        lt2[0] = EventTypes.LiquidationTransferV2({
            symbolHash: 0x2f1991e99a4e22a9e95ff1b67aee336b4047dc47612e36674fa23eb8c6017f2e,
            positionQtyTransfer: -254000000,
            costPositionTransfer: -402465540,
            fee: -7043147,
            markPrice: 15845100000,
            sumUnitaryFundings: 40376000000000000
        });
        EventTypes.LiquidationV2 memory l2 = EventTypes.LiquidationV2({
            accountId: 0xb87c3c901e7df194587586825861c6593ea418156e21ca7521e3806d163e7b5b,
            liquidatedAssetHash: 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa,
            insuranceTransferAmount: 0,
            timestamp: 1715043413487,
            isInsuranceAccount: false,
            liquidationTransfers: lt2
        });
        EventTypes.LiquidationTransferV2[] memory lt3 = new EventTypes.LiquidationTransferV2[](1);
        lt3[0] = EventTypes.LiquidationTransferV2({
            symbolHash: 0x2f1991e99a4e22a9e95ff1b67aee336b4047dc47612e36674fa23eb8c6017f2e,
            positionQtyTransfer: 0,
            costPositionTransfer: 0,
            fee: -7043147,
            markPrice: 15845100000,
            sumUnitaryFundings: 40376000000000000
        });
        EventTypes.LiquidationV2 memory l3 = EventTypes.LiquidationV2({
            accountId: 0xd22bfed15458474d0d4a85dda2b889f47169c0adfca0be5cca0303537b87cd40,
            liquidatedAssetHash: 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa,
            insuranceTransferAmount: 0,
            timestamp: 1715043413487,
            isInsuranceAccount: true,
            liquidationTransfers: lt3
        });
        EventTypes.EventUploadData[] memory events = new EventTypes.EventUploadData[](3);
        events[0] = EventTypes.EventUploadData({bizType: 9, eventId: 2, data: abi.encode(l1)});
        events[1] = EventTypes.EventUploadData({bizType: 9, eventId: 3, data: abi.encode(l2)});
        events[2] = EventTypes.EventUploadData({bizType: 9, eventId: 4, data: abi.encode(l3)});
        EventTypes.EventUpload memory e1 = EventTypes.EventUpload({
            events: events,
            r: 0x3e9b16940a576f215be3375bfc764caf65a05f9ab629c9dfb78981459d631170,
            s: 0x65f0f7aeb82cb27e4dfc89d242369e039d96d50c682f5855858d92d9b74f3f9e,
            v: 0x1b,
            count: 3,
            batchId: 7888
        });

        bool succ = Signature.eventsUploadEncodeHashVerify(e1, addr);
        assertEq(succ, true);
    }

    // https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/723288229/SolWithdraw+Upload
    function test_eventUploadEncodeHash_withdrawSol() public {
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
        EventTypes.WithdrawDataSol memory w2 = EventTypes.WithdrawDataSol({
            tokenAmount: 12356,
            fee: 5001,
            chainId: 902902902,
            accountId: 0xc9b4f2bb0e18cd952f4219d39d9321c860128f8ea74aabe953e110020cb10324,
            r: 0x0,
            s: 0x0,
            sender: 0x320e86426dd1e11d1eb90ec448cdd74b019cd7d30b14c7faa7f35d0aa2226f1c,
            withdrawNonce: 10,
            receiver: 0x320e86426dd1e11d1eb90ec448cdd74b019cd7d30b14c7faa7f35d0aa2226f1c,
            timestamp: 1683270380531,
            brokerId: "woofi_pro",
            tokenSymbol: "USDC"
        });

        EventTypes.EventUploadData[] memory events = new EventTypes.EventUploadData[](2);
        events[0] = EventTypes.EventUploadData({bizType: 1, eventId: 1, data: abi.encode(w1)});
        events[1] = EventTypes.EventUploadData({bizType: 10, eventId: 4, data: abi.encode(w2)});
        EventTypes.EventUpload memory e1 = EventTypes.EventUpload({
            events: events,
            r: 0xd4607b5b0355c1298d4b2f5a815f41fade87bfd185778a12f832f02a8cdb8534,
            s: 0x69714ac2fd7a47500f90344b26ad163561cce1e25146f9e585d9cb1d572f1cda,
            v: 0x1b,
            count: 2,
            batchId: 7888
        });

        bool succ = Signature.eventsUploadEncodeHashVerify(e1, addr);
        assertEq(succ, true);
    }

    function test_solanaWithdraw() public {
        bytes32 hashStruct = keccak256(
            abi.encode(
                keccak256(abi.encodePacked("woofi_pro")),
                keccak256(abi.encodePacked("USDC")),
                902902902,
                0x320e86426dd1e11d1eb90ec448cdd74b019cd7d30b14c7faa7f35d0aa2226f1c,
                3000000,
                2,
                1721702072212,
                Signature.HASH_ORDERLY_NETWORK // salt
            )
        );
        bytes32 k = hex"320e86426dd1e11d1eb90ec448cdd74b019cd7d30b14c7faa7f35d0aa2226f1c";
        bytes32 r = hex"afcf6cc18086132fa4cec878b8ff2a0c5373eef178b032f2774cd481d1d63cb5";
        bytes32 s = hex"223e61115210e0c03ed46dbe1916d6118c2624ab648086dc19a7f332a8eef90e";
        bytes memory m = Bytes32ToAsciiBytes.bytes32ToAsciiBytes(hashStruct);
        bytes32 mAnswer = hex"2f7399516014a7ae683d54a97293deb2265f5efab1feeb6cbb2c5977e0183bb1";
        assertEq(hashStruct, mAnswer);
        bool isSucc = Ed25519.verify(k, r, s, m);
        assertTrue(isSucc);
    }

    function test_solanaTxSignature() public {
        bytes32 k = hex"8d74357c58760282acca9f5af78bb51e2adaa44d6248bb9243116e9ad4a5b4a9";
        bytes32 messageRaw = hex"4d741b6f1eb29cb2a9b9911c82f56fa8d73b04959d3d9d222895df6c0b28aa15";
        bytes memory m = Signature.solanaLedgerSignature(k, messageRaw);
        bytes memory target =
            hex"010002038d74357c58760282acca9f5af78bb51e2adaa44d6248bb9243116e9ad4a5b4a90306466fe5211732ffecadba72c39be7bc8ce5bbc5f7126b2c439b3a40000000054a535a992921064d24e87160da387c7c35b5ddbc92bb81e41fa8404105448d000000000000000000000000000000000000000000000000000000000000000003010009030000000000000000010005020000000002004034643734316236663165623239636232613962393931316338326635366661386437336230343935396433643964323232383935646636633062323861613135";
        assertEq(m, target);
    }

    // https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/930578433/SvWithdraw+Upload
    function test_eventUploadEncodeHash_svWithdraw() public {
        EventTypes.Withdraw2Contract memory w1 = EventTypes.Withdraw2Contract({
            accountId: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed63,
            chainId: 10086,
            sender: 0x6a9961Ace9bF0C1B8B98ba11558A4125B1f5EA3f,
            receiver: 0x6a9961Ace9bF0C1B8B98ba11558A4125B1f5EA3f,
            tokenAmount: 123,
            fee: 5000,
            withdrawNonce: 9,
            timestamp: 1683270380530,
            vaultType: EventTypes.VaultEnum.ProtocolVault,
            clientId: 1,
            brokerHash: 0x1fa6aa88896b69294e9b9f76cd226cafdc04e7d2f8cc1b97764be60be388958a,
            tokenHash: 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa
        });
        EventTypes.EventUploadData[] memory events = new EventTypes.EventUploadData[](1);
        events[0] = EventTypes.EventUploadData({bizType: 11, eventId: 1, data: abi.encode(w1)});
        EventTypes.EventUpload memory e1 = EventTypes.EventUpload({
            events: events,
            r: 0x55b2b89987a236f760fb6ec75e99d8a78a0ff2c6e2cd099cdf6c2747548f95a6,
            s: 0x09be0b1a6afa8285d5b27ec62c2db950320b588693f67f732149c9ad898a00c5,
            v: 0x1c,
            count: 2,
            batchId: 7888
        });

        bool succ = Signature.eventsUploadEncodeHashVerify(e1, addr);
        assertEq(succ, true);
    }
}

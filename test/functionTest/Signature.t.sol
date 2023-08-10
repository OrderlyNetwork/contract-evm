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
                r: 0x8d1009e2d1fbd6e28fc0f63b0d9828b53988c9787c5a46b55c15e23938c4e603,
                s: 0x3778b39bbf4f7e49c31bd408056a989bf43537d7dc2ab405fd447b5f72d027be,
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
                r: 0xc0ee07a021904c41d7e9e0b8aff7937bf7151114bd71ada999a115c3d0e010de,
                s: 0x7166e286fdeb41149e6c6447e72d54f530f6c47009392ef81d8a604c0c229194,
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
            r: 0xad53e90086f612a10d22cc666c1e7428bf2fd094df04a4f95f7f0a9889f6cd3a,
            s: 0x359223d7eefe0d0c691ad58b38ea385cdf4661fafa4bb03a705926c11c025c79,
            v: 0x1b,
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
            r: 0x1640d3c09193a5e5406a4fccf7ad775498ae010c9d1d051c1e3f4fd6f79ebd60,
            s: 0x089137f39069b97d2ef0d2ab1bb935046b2c6f6d0a7ed0bc29e72009a56b5172,
            v: 0x1c,
            maxTimestamp: 1581794149456,
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
            r: 0x1123ab3cab7bd651dee92ef260f21832b3575c4d512d6a68ba50850f78d0d39a,
            s: 0x2c49150d9b81101c02afc844e7473240d159354dbf7992ec913a88f5b259ebd5,
            v: 0x1b,
            maxTimestamp: 1581797148555,
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
}

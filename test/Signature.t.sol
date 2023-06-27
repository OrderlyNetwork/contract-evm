// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/library/Signature.sol";

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
        events[0] = EventTypes.EventUploadData({bizType: 0, eventId: 1, data: abi.encode(w1)});
        events[1] = EventTypes.EventUploadData({bizType: 2, eventId: 3, data: abi.encode(a1)});
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
        events[0] = EventTypes.EventUploadData({bizType: 0, eventId: 1, data: abi.encode(w1)});
        events[1] = EventTypes.EventUploadData({bizType: 2, eventId: 3, data: abi.encode(a1)});
        events[2] = EventTypes.EventUploadData({bizType: 0, eventId: 4, data: abi.encode(w2)});
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
}

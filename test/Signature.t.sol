// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/library/Signature.sol";

contract SignatureTest is Test {
    address constant addr = 0x6a9961Ace9bF0C1B8B98ba11558A4125B1f5EA3f;

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

        bytes32 h =
            Signature.perpUploadEncodeHash(PerpTypes.FuturesTradeUploadData({batchId: 18, count: 4, trades: trades}));
        bytes32 r = 0x8d1009e2d1fbd6e28fc0f63b0d9828b53988c9787c5a46b55c15e23938c4e603; // r
        bytes32 s = 0x3778b39bbf4f7e49c31bd408056a989bf43537d7dc2ab405fd447b5f72d027be; // s
        uint8 v = 0x1b; // v

        bool succ = Signature.verify(h, r, s, v, addr);
        assertEq(succ, true);
    }

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

        bytes32 h =
            Signature.perpUploadEncodeHash(PerpTypes.FuturesTradeUploadData({batchId: 18, count: 4, trades: trades}));
        bytes32 r = 0xc0ee07a021904c41d7e9e0b8aff7937bf7151114bd71ada999a115c3d0e010de;
        bytes32 s = 0x7166e286fdeb41149e6c6447e72d54f530f6c47009392ef81d8a604c0c229194;
        uint8 v = 0x1c;

        bool succ = Signature.verify(h, r, s, v, addr);
        assertEq(succ, true);
    }
}

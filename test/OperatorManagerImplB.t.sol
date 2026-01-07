pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/library/Signature.sol";
import "../src/interface/ILedger.sol";
import "../src/OperatorManagerImplB.sol";
import "../src/OperatorManager.sol";
// import { OperatorManagerImplB } from "../../src/OperatorManagerImplB.sol";

contract OperatorManagerImplBTest is Test{
    OperatorManager om = new OperatorManager();
    OperatorManagerImplB omB = new OperatorManagerImplB();

    function setUp() public {
        vm.startPrank(om.owner());
        om.setOperatorManagerImplB(address(omB));
        om.initBizTypeToSelector();
        vm.stopPrank();



    }
    
    function test_init_selector() public {
        assertTrue(om.bizTypeToSelectors(1) ==  bytes4(keccak256("executeWithdrawAction((uint128,uint128,uint256,bytes32,bytes32,bytes32,uint8,address,uint64,address,uint64,string,string),uint64)")));
        assertTrue(om.bizTypeToSelectors(2) ==  bytes4(keccak256("executeSettlement((bytes32,bytes32,bytes32,int128,uint128,uint64,(bytes32,uint128,int128,int128)[]),uint64)")));
        assertTrue(om.bizTypeToSelectors(3) ==  bytes4(keccak256("executeAdl((bytes32,bytes32,bytes32,int128,int128,uint128,int128,uint64),uint64)")));
        assertTrue(om.bizTypeToSelectors(4) ==  bytes4(keccak256("executeLiquidation((bytes32,bytes32,bytes32,uint128,uint64,(bytes32,bytes32,int128,int128,int128,int128,int128,uint128,int128,uint64)[]),uint64)")));
        assertTrue(om.bizTypeToSelectors(5) ==  bytes4(keccak256("executeFeeDistribution((bytes32,bytes32,uint128,bytes32),uint64)")));
        assertTrue(om.bizTypeToSelectors(6) ==  bytes4(keccak256("executeDelegateSigner((address,address,bytes32,uint256),uint64)")));
        assertTrue(om.bizTypeToSelectors(7) ==  bytes4(keccak256("executeDelegateWithdrawAction((uint128,uint128,uint256,bytes32,bytes32,bytes32,uint8,address,uint64,address,uint64,string,string),uint64)")));
        assertTrue(om.bizTypeToSelectors(8) ==  bytes4(keccak256("executeAdlV2((bytes32,bytes32,int128,int128,uint128,int128,uint64,bool),uint64)")));
        assertTrue(om.bizTypeToSelectors(9) ==  bytes4(keccak256("executeLiquidationV2((bytes32,bytes32,int128,uint64,bool,(bytes32,int128,int128,int128,uint128,int128)[]),uint64)")));
        assertTrue(om.bizTypeToSelectors(10) ==  bytes4(keccak256("executeWithdrawSolAction((uint128,uint128,uint256,bytes32,bytes32,bytes32,bytes32,bytes32,uint64,uint64,string,string),uint64)")));
        assertTrue(om.bizTypeToSelectors(11) ==  bytes4(keccak256("executeWithdraw2Contract((uint128,uint128,uint256,bytes32,uint8,address,uint64,address,uint64,bytes32,bytes32,uint256),uint64)")));
        assertTrue(om.bizTypeToSelectors(12) ==  bytes4(keccak256("executeBalanceTransfer((bytes32,bytes32,uint128,bytes32,bool,uint8,uint256),uint64)")));            
        assertTrue(om.bizTypeToSelectors(13) ==  bytes4(keccak256("executeSwapResultUpload((bytes32,bytes32,bytes32,int128,int128,uint256,uint8),uint64)")));
        assertTrue(om.bizTypeToSelectors(14) ==  bytes4(keccak256("executeWithdraw2ContractV2((uint128,uint128,uint8,uint8,uint256,bytes32,uint8,bytes32,uint64,bytes32,uint64,bytes32,bytes32,uint256),uint64)")));
    }


    // test the encoded calldata 
    function test_ledger_selector() public {
        bytes memory selectorCodedCalldata;
        bytes memory manuallyCodedCalldata;
        EventTypes.EventUploadData[] memory events = new EventTypes.EventUploadData[](1);
        // Withdraw
        {
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
            
            events[0] = EventTypes.EventUploadData({bizType: 1, eventId: 1, data: abi.encode(w1)});
            selectorCodedCalldata = abi.encodeWithSelector(ILedger.executeWithdrawAction.selector, abi.decode(events[0].data, (EventTypes.WithdrawData)), events[0].eventId);

            vm.prank(address(om));
            // Simulate cross-chain function call to convert the memroy into calldata type
            manuallyCodedCalldata = this._manuallyEncodePacked(events[0]);
            assertEq(selectorCodedCalldata, manuallyCodedCalldata);
        }
        // Settlement
        {
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
            events[0] = EventTypes.EventUploadData({bizType: 2, eventId: 7, data: abi.encode(s1)});
            selectorCodedCalldata = abi.encodeWithSelector(ILedger.executeSettlement.selector, abi.decode(events[0].data, (EventTypes.Settlement)), events[0].eventId);
            
            // Simulate cross-chain function call to convert the memroy into calldata type
            manuallyCodedCalldata = this._manuallyEncodePacked(events[0]);
            assertEq(selectorCodedCalldata, manuallyCodedCalldata);
        }
        // Adl
        {
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
            events[0] = EventTypes.EventUploadData({bizType: 3, eventId: 3, data: abi.encode(a1)});
            selectorCodedCalldata = abi.encodeWithSelector(ILedger.executeAdl.selector, abi.decode(events[0].data, (EventTypes.Adl)), events[0].eventId);
            
            // Simulate cross-chain function call to convert the memroy into calldata type
            manuallyCodedCalldata = this._manuallyEncodePacked(events[0]);
            assertEq(selectorCodedCalldata, manuallyCodedCalldata);
        }
        // Liquidation
        {
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

            events[0] = EventTypes.EventUploadData({bizType: 4, eventId: 9, data: abi.encode(l1)});
            selectorCodedCalldata = abi.encodeWithSelector(ILedger.executeLiquidation.selector, abi.decode(events[0].data, (EventTypes.Liquidation)), events[0].eventId);
            
            // Simulate cross-chain function call to convert the memroy into calldata type
            manuallyCodedCalldata = this._manuallyEncodePacked(events[0]);
            assertEq(selectorCodedCalldata, manuallyCodedCalldata);

        }
        // FeeDistribution
        {
            EventTypes.FeeDistribution memory fee1 = EventTypes.FeeDistribution({
                fromAccountId: 0xc69f41c55c00e4d875b3e82eeb0fcda3de2090a10130baf3c1ffee0f2e7ce243,
                toAccountId: 0x9ff99a5d6cb71a3ef897b0fff5f5801af6dc5f72d8f1608e61409b8fc965bd68,
                amount: 6435342234,
                tokenHash: 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa
            });
            events[0] = EventTypes.EventUploadData({bizType: 5, eventId: 1277, data: abi.encode(fee1)});
            selectorCodedCalldata = abi.encodeWithSelector(ILedger.executeFeeDistribution.selector, abi.decode(events[0].data, (EventTypes.FeeDistribution)), events[0].eventId);
            
            // Simulate cross-chain function call to convert the memroy into calldata type
            manuallyCodedCalldata = this._manuallyEncodePacked(events[0]);
            assertEq(selectorCodedCalldata, manuallyCodedCalldata);

        }
        // DelegateSigner
        {
            EventTypes.DelegateSigner memory delegateSigner1 = EventTypes.DelegateSigner({
                delegateSigner: 0xa3255bb283A607803791ba8A202262f4AB28b0B2,
                delegateContract: 0xa757D29D25116a657F2929DE61BCcA6173f731fE,
                brokerHash: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed66,
                chainId: 42162
            });
            events[0] = EventTypes.EventUploadData({bizType: 6, eventId: 235, data: abi.encode(delegateSigner1)});

            selectorCodedCalldata = abi.encodeWithSelector(ILedger.executeDelegateSigner.selector, abi.decode(events[0].data, (EventTypes.DelegateSigner)), events[0].eventId);
            
            // Simulate cross-chain function call to convert the memroy into calldata type
            manuallyCodedCalldata = this._manuallyEncodePacked(events[0]);
            assertEq(selectorCodedCalldata, manuallyCodedCalldata);
        }
        // DelegateWithdraw
        {
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
            events[0] = EventTypes.EventUploadData({bizType: 7, eventId: 4, data: abi.encode(delegateWithdraw0)});
            selectorCodedCalldata = abi.encodeWithSelector(ILedger.executeDelegateWithdrawAction.selector, abi.decode(events[0].data, (EventTypes.WithdrawData)), events[0].eventId);
            
            // Simulate cross-chain function call to convert the memroy into calldata type
            manuallyCodedCalldata = this._manuallyEncodePacked(events[0]);
            assertEq(selectorCodedCalldata, manuallyCodedCalldata);
        }
        // AdlV2
        {
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
            events[0] = EventTypes.EventUploadData({bizType: 8, eventId: 2, data: abi.encode(a1)});
            selectorCodedCalldata = abi.encodeWithSelector(ILedger.executeAdlV2.selector, abi.decode(events[0].data, (EventTypes.AdlV2)), events[0].eventId);
            
            // Simulate cross-chain function call to convert the memroy into calldata type
            manuallyCodedCalldata = this._manuallyEncodePacked(events[0]);
            assertEq(selectorCodedCalldata, manuallyCodedCalldata);

        }
        // Liquidation V2
        {
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

            events[0] = EventTypes.EventUploadData({bizType: 9, eventId: 2, data: abi.encode(l1)});
            selectorCodedCalldata = abi.encodeWithSelector(ILedger.executeLiquidationV2.selector, abi.decode(events[0].data, (EventTypes.LiquidationV2)), events[0].eventId);
            
            // Simulate cross-chain function call to convert the memroy into calldata type
            manuallyCodedCalldata = this._manuallyEncodePacked(events[0]);
            assertEq(selectorCodedCalldata, manuallyCodedCalldata);
        }
        // WithdrawSol
        {
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

            events[0] = EventTypes.EventUploadData({bizType: 10, eventId: 4, data: abi.encode(w2)});
            selectorCodedCalldata = abi.encodeWithSelector(ILedger.executeWithdrawSolAction.selector, abi.decode(events[0].data, (EventTypes.WithdrawDataSol)), events[0].eventId);
            
            // Simulate cross-chain function call to convert the memroy into calldata type
            manuallyCodedCalldata = this._manuallyEncodePacked(events[0]);
            assertEq(selectorCodedCalldata, manuallyCodedCalldata);

        }
        // Withdraw2Contract
        {
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
            events[0] = EventTypes.EventUploadData({bizType: 11, eventId: 1, data: abi.encode(w1)});
            selectorCodedCalldata = abi.encodeWithSelector(ILedger.executeWithdraw2Contract.selector, abi.decode(events[0].data, (EventTypes.Withdraw2Contract)), events[0].eventId);
            
            // Simulate cross-chain function call to convert the memroy into calldata type
            manuallyCodedCalldata = this._manuallyEncodePacked(events[0]);
            assertEq(selectorCodedCalldata, manuallyCodedCalldata);
        }
        // BalanceTransfer
        {
            EventTypes.BalanceTransfer memory b1 = EventTypes.BalanceTransfer({
                fromAccountId: 0x9ff99a5d6cb71a3ef897b0fff5f5801af6dc5f72d8f1608e61409b8fc965bd68,  
                toAccountId: 0xaff99a5d6cb71a3ef897b0fff5f5801af6dc5f72d8f1608e61409b8fc965bd68,      
                amount: 1231245125,
                tokenHash: 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa,
                isFromAccountId: true,
                transferType: 3,         
                transferId: 123
            });
            events[0] = EventTypes.EventUploadData({bizType: 12, eventId: 1274, data: abi.encode(b1)});
            selectorCodedCalldata = abi.encodeWithSelector(ILedger.executeBalanceTransfer.selector, abi.decode(events[0].data, (EventTypes.BalanceTransfer)), events[0].eventId);
            
            // Simulate cross-chain function call to convert the memroy into calldata type
            manuallyCodedCalldata = this._manuallyEncodePacked(events[0]);
            assertEq(selectorCodedCalldata, manuallyCodedCalldata);
        }
        // SwapResult
        {
            EventTypes.SwapResult memory s1 = EventTypes.SwapResult({
                accountId: 0x9ff99a5d6cb71a3ef897b0fff5f5801af6dc5f72d8f1608e61409b8fc965bd68,
                buyTokenHash: 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa,
                sellTokenHash: 0x8b1a1d9c2b109e527c9134b25b1a1833b16b6594f92daa9f6d9b7a6024bce9d0,
                buyQuantity: 1235364323,
                sellQuantity: -124124,
                chainId: 421614,
                swapStatus: 0
            });
            events[0] = EventTypes.EventUploadData({bizType: 13, eventId: 1274, data: abi.encode(s1)});
            selectorCodedCalldata = abi.encodeWithSelector(ILedger.executeSwapResultUpload.selector, abi.decode(events[0].data, (EventTypes.SwapResult)), events[0].eventId);
            
            // Simulate cross-chain function call to convert the memroy into calldata type
            manuallyCodedCalldata = this._manuallyEncodePacked(events[0]);
            assertEq(selectorCodedCalldata, manuallyCodedCalldata);
        }
        // Withdraw2ContractV2
        {
            EventTypes.Withdraw2ContractV2 memory w1 = EventTypes.Withdraw2ContractV2({
                brokerHash: 0x6ca2f644ef7bd6d75953318c7f2580014941e753b3c6d54da56b3bf75dd14dfc,
                tokenAmount: 123,
                fee: 5000,
                accountId: 0x1723cb226c337a417a6022890bc5671ebb4db551db0273536bf1094edf39ed63,
                chainId: 10086,
                sender: bytes32(abi.encode(address(this))),
                receiver: 0x0fb9ba52b1f09445f1e3a7508d59f0797923acf744fbe2da303fb06da859ee87,
                withdrawNonce: 9,
                timestamp: 1683270380530,
                vaultType: EventTypes.VaultEnum.Ceffu,
                senderChainType: EventTypes.ChainType.EVM,
                receiverChainType: EventTypes.ChainType.SOL,
                tokenHash: 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa,
                clientId: 0
            });
            events[0] = EventTypes.EventUploadData({bizType: 14, eventId: 1, data: abi.encode(w1)});

            selectorCodedCalldata = abi.encodeWithSelector(ILedger.executeWithdraw2ContractV2.selector, abi.decode(events[0].data, (EventTypes.Withdraw2ContractV2)), events[0].eventId);
            
            // Simulate cross-chain function call to convert the memroy into calldata type
            manuallyCodedCalldata = this._manuallyEncodePacked(events[0]);
            assertEq(selectorCodedCalldata, manuallyCodedCalldata);
        } 
    }

    function _manuallyEncodePacked(EventTypes.EventUploadData calldata data) public view returns (bytes memory) {
        bytes4 selector = om.bizTypeToSelectors(data.bizType);

        uint256 dataOffset = 0;
        if (_isDynamicBizType(data.bizType)) {
            dataOffset = 32;
        }
        
        require(data.data.length >= dataOffset, "Data too short");
        bytes memory dataWithoutOffset = abi.encodePacked(data.data[dataOffset:]);
        uint256 eventOffset = 64;   // 0x40 for eventOffset + eventId
        // encode schema for static or dynamic event types
        bytes memory encodedCalldata = dataOffset == 0
        ? abi.encodePacked(selector, dataWithoutOffset, abi.encode(data.eventId))
        : abi.encodePacked(selector, abi.encode(eventOffset), abi.encode(data.eventId), dataWithoutOffset);

        return encodedCalldata;
    }

    function _isDynamicBizType(uint8 bizType) internal pure returns (bool) {
        return
            bizType == uint8(Signature.BizType.Withdraw) ||
            bizType == uint8(Signature.BizType.Settlement) ||
            bizType == uint8(Signature.BizType.Liquidation) ||
            bizType == uint8(Signature.BizType.DelegateWithdraw) ||
            bizType == uint8(Signature.BizType.LiquidationV2) ||
            bizType == uint8(Signature.BizType.WithdrawSol);
    }

}
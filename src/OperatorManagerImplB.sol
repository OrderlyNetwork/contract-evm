// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.26;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "./dataLayout/OperatorManagerDataLayout.sol";
import "./interface/IOperatorManagerImplB.sol";
import "./library/Signature.sol";


/// @title OperatorManager contract, implementation part B contract, for resolve EIP170 limit
/// @author Orderly_Rubick
contract OperatorManagerImplB is IOperatorManagerImplB, OwnableUpgradeable, OperatorManagerDataLayout {
    constructor() {
        _disableInitializers();
    }

    /// @notice Function for event upload
    function eventUpload(EventTypes.EventUpload calldata data) external override {
        if (data.batchId != eventUploadBatchId) revert BatchIdNotMatch(data.batchId, eventUploadBatchId);
        _innerPing();
        _eventUploadData(data);
        // emit event
        emit EventUpload(data.batchId);
        // next wanted eventUploadBatchId
        eventUploadBatchId += 1;
    }

    /// @notice Function to verify Engine signature for event upload data, if validated then Ledger contract will be called to execute the event process
    function _eventUploadData(EventTypes.EventUpload calldata data) internal {
        EventTypes.EventUploadData[] calldata events = data.events; // gas saving
        if (events.length != data.count) revert CountNotMatch(events.length, data.count);

        // check engine signature
        bool succ = Signature.eventsUploadEncodeHashVerify(data, engineEventUploadAddress);
        if (!succ) revert SignatureNotMatch();

        // process each event upload
        for (uint256 i = 0; i < data.count; i++) {
            _processEventUpload(events[i]);
        }
    }

    /// @notice Cross-Contract call to Ledger contract to process each event upload according to the event type
    function _processEventUpload(EventTypes.EventUploadData calldata data) internal {
        bytes4 selector = bizTypeToSelectors[data.bizType];
        if (selector == bytes4(0))  revert InvalidBizType(data.bizType);

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
        (bool success, bytes memory returnData) = address(ledger).call(encodedCalldata);
        
        if (!success) {
            if (returnData.length == 0) revert("Ledger call failed");
            assembly {
                revert(add(32, returnData), mload(returnData))
            }
        }        
    }

    /// @notice Function to update last operator interaction timestamp
    function _innerPing() internal {
        lastOperatorInteraction = block.timestamp;
    }

    // @dev Check if the bizType has a dynamic abi.encode schema
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

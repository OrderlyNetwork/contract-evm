// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

/// @title CrossChainMessageTypes library
/// @author Orderly_Rubick
library CrossChainMessageTypes {
    // The structure of the message
    struct MessageV1 {
        uint256 srcChainId; // Source blockchain ID
        uint256 dstChainId; // Target blockchain ID
        bytes32 accountId; // Account address converted to string
        address addr; // Account address
        bytes32 tokenHash; // Token symbol for transfer
        uint256 tokenAmount; // Amount of token for transfer
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

library CrossChainMessageTypes {
    // The structure of the message
    struct MessageV1 {
        uint256 srcChainId; // Source blockchain ID
        uint256 dstChainId; // Target blockchain ID
        bytes32 accountId; // Account address converted to string
        address addr; // Account address
        bytes32 tokenSymbol; // Token symbol for transfer
        uint256 tokenAmount; // Amount of token for transfer
    }
}

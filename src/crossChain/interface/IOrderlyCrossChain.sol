// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// Interface for the Cross Chain Operations
interface IOrderlyCrossChain {
    // Event to be emitted when a message is sent
    event MessageSent(
        bytes payload,
        uint srcChainId,
        uint dstChainId,
        address contractAddress
    );

    // Event to be emitted when a message is received
    event MessageReceived(
        bytes payload,
        uint srcChainId,
        uint dstChainId,
        address contractAddress
    );

    /**
     * Send a message to another chain
     *
     * @param payload The payload to be sent to the other chain
     */
    function sendMessage(
        bytes calldata payload,
        uint srcChainId,
        uint dstChainId,
        address contractAddress
    ) external;

    /**
     * Receive a message from another chain
     *
     * @param payload The payload received from the other chain
     */
    function receiveMessage(
        bytes calldata payload,
        uint srcChainId,
        uint dstChainId,
        address contractAddress
    ) external;
}

// Interface for the Cross Chain Receiver
interface IOrderlyCrossChainReceiver {
    /**
     * Receive a message from another chain
     *
     * @param payload The payload received from the other chain
     */
    function receiveMessage(
        bytes memory payload,
        uint srcChainId,
        uint dstChainId
    ) external;
}

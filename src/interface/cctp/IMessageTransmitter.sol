// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

interface IMessageTransmitter {
    function receiveMessage(bytes calldata message, bytes calldata attestation) external returns (bool success);
}

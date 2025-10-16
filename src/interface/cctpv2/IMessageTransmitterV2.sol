// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

interface IMessageTransmitterV2 {
    function receiveMessage(bytes calldata message, bytes calldata attestation) external;
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./types/PerpTypes.sol";

library Signature {
    function getEthSignedMessageHash(bytes32 _messageHash) public pure returns (bytes32) {
        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash));
    }

    function verify(bytes32 hash, bytes32 r, bytes32 s, uint8 v, address signer) public pure returns (bool) {
        return ecrecover(hash, v, r, s) == signer;
    }

    function perpUploadEncodeHash(PerpTypes.FuturesTradeUploadData calldata data) public pure returns (bytes32) {
        bytes memory encoded = abi.encode(data.batchId, data.count, data.trades);
        return getEthSignedMessageHash(keccak256(encoded));
    }
}

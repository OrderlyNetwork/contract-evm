// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

library VaultTypes {
    struct VaultDeposit {
        bytes32 accountId;
        address userAddress;
        uint256 tokenAmount;
        bytes32 tokenHash;
        bytes32 brokerHash;
    }

    struct VaultWithdraw {
        bytes32 accountId;
        address sender;
        address receiver;
        bytes32 brokerHash;
        bytes32 tokenHash;
        uint256 tokenAmount;
        uint256 fee;
        uint64 withdrawNonce; // withdraw nonce
    }
}

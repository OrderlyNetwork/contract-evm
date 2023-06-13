// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

library VaultTypes {
    struct VaultDepositFE {
        bytes32 accountId;
        bytes32 brokerHash;
        bytes32 tokenHash;
        uint256 tokenAmount;
    }

    struct VaultDeposit {
        bytes32 accountId;
        address userAddress;
        bytes32 brokerHash;
        bytes32 tokenHash;
        uint256 tokenAmount;
        uint64 depositNonce; // deposit nonce
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

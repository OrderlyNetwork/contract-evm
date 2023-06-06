// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

library VaultTypes {
    struct VaultDeposit {
        bytes32 accountId;
        address userAddress;
        uint256 tokenAmount;
        bytes32 tokenSymbol;
        bytes32 brokerId;
    }

    struct VaultWithdraw {
        bytes32 accountId;
        address userAddress;
        uint256 withdrawNonce;
        bytes32 tokenSymbol;
        uint256 tokenAmount;
    }
}

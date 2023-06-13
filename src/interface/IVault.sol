// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./../library/types/VaultTypes.sol";

interface IVault {
    event AccountDeposit(
        bytes32 indexed accountId,
        address indexed userAddress,
        uint64 indexed depositNonce,
        bytes32 tokenHash,
        uint256 tokenAmount
    );

    event AccountWithdraw(
        bytes32 indexed accountId,
        uint64 indexed withdrawNonce,
        bytes32 brokerHash,
        address sender,
        address receiver,
        bytes32 tokenHash,
        uint256 tokenAmount,
        uint256 fee,
        uint256 blocktime
    );

    function deposit(VaultTypes.VaultDepositFE calldata data) external;
    function withdraw(VaultTypes.VaultWithdraw calldata data) external;
}

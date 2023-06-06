// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./../library/types/VaultTypes.sol";

interface IVault {
    event AccountDeposit(
        bytes32 indexed accountId,
        address indexed userAddress,
        uint256 indexed depositNonce,
        bytes32 tokenSymbol,
        uint256 tokenAmount
    );
    event AccountWithdraw(
        bytes32 indexed accountId,
        address indexed userAddress,
        uint256 indexed withdrawNonce,
        bytes32 tokenSymbol,
        uint256 tokenAmount
    );

    function deposit(VaultTypes.VaultDeposit calldata data) external;
    function withdraw(VaultTypes.VaultWithdraw calldata data) external;
}

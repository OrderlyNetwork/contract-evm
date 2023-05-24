// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

interface IVault {
    event DepositEvent(bytes32 indexed accountId, address indexed addr, bytes32 indexed symbol, uint256 amount);
    event WithdrawEvent(bytes32 indexed accountId, address indexed addr, bytes32 indexed symbol, uint256 amount);

    function deposit(bytes32 accountId, bytes32 tokenSymbol, uint256 tokenAmount) external;
    function withdraw(bytes32 accountId, address addr, bytes32 tokenSymbol, uint256 tokenAmount) external;
}

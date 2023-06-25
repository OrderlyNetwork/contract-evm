// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./../library/types/VaultTypes.sol";

interface IVault {
    error OnlyCrossChainManagerCanCall();
    error TokenNotAllowed();
    error BrokerNotAllowed();
    error TransferFromFailed();
    error TransferFailed();
    error BalanceNotEnough(uint256 balance, uint128 amount);

    event AccountDeposit(
        bytes32 indexed accountId,
        address indexed userAddress,
        uint64 indexed depositNonce,
        bytes32 tokenHash,
        uint128 tokenAmount
    );

    event AccountWithdraw(
        bytes32 indexed accountId,
        uint64 indexed withdrawNonce,
        bytes32 brokerHash,
        address sender,
        address receiver,
        bytes32 tokenHash,
        uint128 tokenAmount,
        uint128 fee,
        uint256 blocktime
    );

    function deposit(VaultTypes.VaultDepositFE calldata data) external;
    function withdraw(VaultTypes.VaultWithdraw calldata data) external;

    // admin call
    function setCrossChainManager(address _crossChainManagerAddress) external;
    function addToken(bytes32 _tokenHash, address _tokenAddress) external;
    function addBroker(bytes32 _brokerHash) external;
}

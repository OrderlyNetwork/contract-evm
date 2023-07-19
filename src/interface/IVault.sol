// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./../library/types/VaultTypes.sol";

interface IVault {
    error OnlyCrossChainManagerCanCall();
    error AccountIdInvalid();
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

    function initialize() external;

    function deposit(VaultTypes.VaultDepositFE calldata data) external;
    function withdraw(VaultTypes.VaultWithdraw calldata data) external;

    // admin call
    function setCrossChainManager(address _crossChainManagerAddress) external;
    function setAllowedToken(bytes32 _tokenHash, bool _allowed) external;
    function setAllowedBroker(bytes32 _brokerHash, bool _allowed) external;
    function changeTokenAddressAndAllow(bytes32 _tokenHash, address _tokenAddress) external;
    function getAllowedToken(bytes32 _tokenHash) external view returns (address);
    function getAllowedBroker(bytes32 _brokerHash) external view returns (bool);
    function getAllAllowedToken() external view returns (bytes32[] memory);
    function getAllAllowedBroker() external view returns (bytes32[] memory);
}

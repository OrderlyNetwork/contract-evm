// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

enum PayloadType {
    LP_DEPOSIT,
    SP_DEPOSIT,
    LP_WITHDRAW,
    SP_WITHDRAW,
    ASSETS_DISTRIBUTION,
    UPDATE_USER_CLAIM
}

struct DepositParams {
    PayloadType payloadType;
    address receiver;
    address token;
    uint256 amount;
    bytes32 brokerHash;
}

/// @title IProtocolVault Interface
interface IProtocolVault {
    function depositFromStrategy(uint256 periodId, address token, uint256 amount) external;
}

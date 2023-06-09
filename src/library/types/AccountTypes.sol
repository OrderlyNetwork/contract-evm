// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

library AccountTypes {
    struct PerpPosition {
        int256 positionQty;
        int256 cost_position;
        int256 lastSumUnitaryFundings;
        uint256 lastExecutedPrice;
    }

    // account id, unique for each account, should be accountId -> {addr, brokerId}
    // and keccak256(addr, brokerID) == accountId
    struct Account {
        // user's broker id
        bytes32 brokerHash;
        // primary address
        address userAddress;
        // lastwithdraw nonce
        uint64 lastWithdrawNonce;
        // mapping symbol => balance
        mapping(bytes32 => uint256) balances;
        // mapping symbol => totalFrozenBalance
        mapping(bytes32 => uint256) totalFrozenBalances;
        // mapping withdrawNonce => symbol => balance
        mapping(uint64 => mapping(bytes32 => uint256)) frozenBalances; 
        // last perp trade id
        uint256 lastPerpTradeId;
        // last cefi event id
        uint256 lastCefiEventId;
        // perp position
        mapping(bytes32 => PerpPosition) perpPositions;
        // reentrancy lock
        bool hasPendingLedgerRequest;
    }

    struct AccountDeposit {
        bytes32 accountId;
        bytes32 brokerHash;
        address userAddress;
        bytes32 tokenHash;
        uint256 tokenAmount;
        uint256 srcChainId;
        uint256 srcChainDepositNonce;
    }

    // for accountWithdrawFinish
    struct AccountWithdraw {
        bytes32 accountId;
        address sender;
        address receiver;
        bytes32 brokerHash;
        bytes32 tokenHash;
        uint256 tokenAmount;
        uint256 fee;
        uint256 chainId;
        uint64 withdrawNonce;
    }
}

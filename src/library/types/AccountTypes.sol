// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

library AccountTypes {
    struct PerpPosition {
        int128 positionQty;
        int128 costPosition;
        int128 lastSumUnitaryFundings;
        uint128 lastExecutedPrice;
        uint128 lastSettledPrice;
        uint128 averageEntryPrice;
        int128 openingCost;
        uint128 lastAdlPrice;
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
        mapping(bytes32 => uint128) balances;
        // mapping symbol => totalFrozenBalance
        mapping(bytes32 => uint128) totalFrozenBalances;
        // mapping withdrawNonce => symbol => balance
        mapping(uint64 => mapping(bytes32 => uint128)) frozenBalances;
        // last perp trade id
        uint64 lastPerpTradeId;
        // last cefi event id
        uint64 lastCefiEventId;
        // last deposit event id
        uint64 lastDepositEventId;
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
        uint128 tokenAmount;
        uint256 srcChainId;
        uint64 srcChainDepositNonce;
    }

    // for accountWithdrawFinish
    struct AccountWithdraw {
        bytes32 accountId;
        address sender;
        address receiver;
        bytes32 brokerHash;
        bytes32 tokenHash;
        uint128 tokenAmount;
        uint128 fee;
        uint256 chainId;
        uint64 withdrawNonce;
    }
}

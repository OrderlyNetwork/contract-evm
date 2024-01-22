// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

/// @title AccountTypes library
/// @author Orderly_Rubick
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
        // mapping symbol => balance
        mapping(bytes32 => uint128) balances;
        // mapping symbol => totalFrozenBalance
        mapping(bytes32 => uint128) totalFrozenBalances;
        // mapping withdrawNonce => symbol => balance
        mapping(uint64 => mapping(bytes32 => uint128)) frozenBalances;
        // perp position
        mapping(bytes32 => PerpPosition) perpPositions;
        // lastwithdraw nonce
        uint64 lastWithdrawNonce;
        // last perp trade id
        uint64 lastPerpTradeId;
        // last engine event id
        uint64 lastEngineEventId;
        // last deposit event id
        uint64 lastDepositEventId;
    }

    struct AccountDeposit {
        bytes32 accountId;
        bytes32 brokerHash;
        address userAddress;
        bytes32 tokenHash;
        uint256 srcChainId;
        uint128 tokenAmount;
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

    struct AccountTokenBalances {
        // token hash
        bytes32 tokenHash;
        // balance & frozenBalance
        uint128 balance;
        uint128 frozenBalance;
    }

    struct AccountPerpPositions {
        // symbol hash
        bytes32 symbolHash;
        // perp position
        int128 positionQty;
        int128 costPosition;
        int128 lastSumUnitaryFundings;
        uint128 lastExecutedPrice;
        uint128 lastSettledPrice;
        uint128 averageEntryPrice;
        int128 openingCost;
        uint128 lastAdlPrice;
    }

    // for batch get
    struct AccountSnapshot {
        bytes32 accountId;
        bytes32 brokerHash;
        address userAddress;
        uint64 lastWithdrawNonce;
        uint64 lastPerpTradeId;
        uint64 lastEngineEventId;
        uint64 lastDepositEventId;
        AccountTokenBalances[] tokenBalances;
        AccountPerpPositions[] perpPositions;
    }

    struct AccountDelegateSigner {
        uint256 chainId;
        address signer;
    }
}

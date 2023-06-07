// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

// EnumerableSet
import "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

library AccountTypes {
    using EnumerableSet for EnumerableSet.AddressSet;

    int256 constant FUNDING_MOVE_RIGHT_PRECISIONS = 100000000000000000;
    bytes32 constant USDC = "USDC";

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
        // withdraw nonce
        uint256 withdrawNonce;
        // mapping symbol => balance
        mapping(bytes32 => uint256) balances;
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

    // charge funding fee
    function chargeFundingFee(PerpPosition storage position, int256 sumUnitaryFundings) public {
        int256 accruedFeeUncoverted = position.positionQty * (sumUnitaryFundings - position.lastSumUnitaryFundings);
        int256 accruedFee = accruedFeeUncoverted / FUNDING_MOVE_RIGHT_PRECISIONS;
        int256 remainder = accruedFeeUncoverted - (accruedFee * FUNDING_MOVE_RIGHT_PRECISIONS);
        if (remainder > 0) {
            accruedFee += 1;
        }
        position.cost_position += accruedFee;
        position.lastSumUnitaryFundings = sumUnitaryFundings;
    }
}

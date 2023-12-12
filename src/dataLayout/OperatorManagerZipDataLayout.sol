// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../interface/IOperatorManager.sol";
import "../library/types/PerpTypes.sol";

/// @title OperatorManagerZip contract data layout
/// @author Orderly_Zion
/// @notice DataLayout for OperatorManagerZip contract, align with 50 slots
contract OperatorManagerZipDataLayout {
    // An EOA operator address, for zip contract to call
    address public zipOperatorAddress;
    // The opeartorManager Interface
    IOperatorManager public operatorManager;
    // mapping symbolHash from uint8 to bytes32
    mapping(uint8 => bytes32) public symbolId2Hash;

    // The storage gap to prevent overwriting by proxy
    uint256[47] private __gap;
}

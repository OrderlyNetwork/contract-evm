// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

/// @title Utils library
/// @author Orderly_Rubick
library Utils {
    function getAccoundId(address _userAddr, string memory _brokerId) internal pure returns (bytes32) {
        return keccak256(abi.encode(_userAddr, keccak256(abi.encodePacked(_brokerId))));
    }

    function calculateStringHash(string memory _str) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_str));
    }

    function validateAccountId(bytes32 _accountId, bytes32 _brokerHash, address _userAddress)
        internal
        pure
        returns (bool)
    {
        return keccak256(abi.encode(_userAddress, _brokerHash)) == _accountId;
    }

    function toBytes32(address addr) public pure returns (bytes32) {
        return bytes32(abi.encodePacked(addr));
    }
}

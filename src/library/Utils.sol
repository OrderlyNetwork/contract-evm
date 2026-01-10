// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

/// @title Utils library
/// @author Orderly_Rubick Orderly_Zion
library Utils {
    // legacy account id
    function getAccountId(address _userAddr, string memory _brokerId) internal pure returns (bytes32) {
        return keccak256(abi.encode(_userAddr, calculateStringHash(_brokerId)));
    }

    // legacy account id
    function calculateAccountId(address _userAddr, bytes32 _brokerHash) internal pure returns (bytes32) {
        return keccak256(abi.encode(_userAddr, _brokerHash));
    }

    // pv account id
    function calculateStrategyVaultAccountId(address _vault, address _userAddr, bytes32 _brokerHash)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_vault, _userAddr, _brokerHash));
    }

    function calculateStringHash(string memory _str) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_str));
    }

    // legacy account id for evm
    function validateAccountId(bytes32 _accountId, bytes32 _brokerHash, address _userAddress)
        internal
        pure
        returns (bool)
    {
        return keccak256(abi.encode(_userAddress, _brokerHash)) == _accountId;
    }

    // legacy account id for solana
    function validateAccountId(bytes32 _accountId, bytes32 _brokerHash, bytes32 _userAddress)
        internal
        pure
        returns (bool)
    {
        return keccak256(abi.encode(_userAddress, _brokerHash)) == _accountId;
    }

    function validateStrategyVaultAccountId(
        address _vault,
        bytes32 _accountId,
        bytes32 _brokerHash,
        address _userAddress
    ) internal pure returns (bool) {
        return calculateStrategyVaultAccountId(_vault, _userAddress, _brokerHash) == _accountId;
    }

    // both legacy accountId and pv accountId are valid
    function validateExtendedAccountId(address _vault, bytes32 _accountId, bytes32 _brokerHash, address _userAddress)
        internal
        pure
        returns (bool)
    {
        return validateAccountId(_accountId, _brokerHash, _userAddress)
            || validateStrategyVaultAccountId(_vault, _accountId, _brokerHash, _userAddress);
    }

    function toBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(abi.encode(addr));
    }

    function bytes32ToAddress(bytes32 _bytes32) internal pure returns (address) {
        return address(uint160(uint256(_bytes32)));
    }

    function bytes32ToBytes(bytes32 _bytes32) internal pure returns (bytes memory) {
        return abi.encodePacked(_bytes32);
    }
}

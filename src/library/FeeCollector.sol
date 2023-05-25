// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

// WIP @Rubick
abstract contract FeeCollector is Ownable {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    struct Fee {
        // balance
        mapping(bytes32 => uint256) balances;
        // other meta
        uint256 feeRate;
    }

    bytes32 public feeCollectorAddress;
    EnumerableSet.Bytes32Set private brokerIdSet;
    // Fee is a struct contains balance, feeRate, etc.
    mapping(bytes32 => Fee) id2FeeValue;

    // set feeCollectorAddress
    function setFeeCollectorAddress(bytes32 _feeCollectorAddress) public onlyOwner {
        feeCollectorAddress = _feeCollectorAddress;
    }

    // add balance to feeCollector
    function addFeeCollectorBalance(bytes32 symbol, uint256 _balance) public onlyOwner {
        id2FeeValue[feeCollectorAddress].balances[symbol] += _balance;
    }

    // add new brokerId
    function addBrokerId(bytes32 _brokerId) public onlyOwner {
        require(!EnumerableSet.contains(brokerIdSet, _brokerId), "brokerId already exist");
        EnumerableSet.add(brokerIdSet, _brokerId);
    }

    // add balance to brokerId
    function addBalance(bytes32 _brokerId, uint256 _balance) public onlyOwner {
        require(EnumerableSet.contains(brokerIdSet, _brokerId), "brokerId not exist");
        Fee storage fee = id2FeeValue[_brokerId];
        fee.balances[_brokerId] += _balance;
    }

    // get brokerId List. O(n)
    function getBrokerIdList() public view returns (bytes32[] memory) {
        return EnumerableSet.values(brokerIdSet);
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableMap.sol";
import "../../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

// WIP @rubick
abstract contract FeeCollector is Ownable {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableMap for EnumerableMap.Bytes32ToUintMap;

    address public feeCollectorAddress;
    uint256 public feeCollectorBalance;
    EnumerableSet.Bytes32Set private brokerIdSet;
    // TODO refactor to a struct contains balance, feeRate, etc.
    EnumerableMap.Bytes32ToUintMap private brokerId2Balance;

    // set feeCollectorAddress
    function setFeeCollectorAddress(address _feeCollectorAddress) public onlyOwner {
        feeCollectorAddress = _feeCollectorAddress;
    }

    // add balance to feeCollector
    function addFeeCollectorBalance(uint256 _balance) public onlyOwner {
        feeCollectorBalance += _balance;
    }

    // add new brokerId
    function addBrokerId(bytes32 _brokerId) public onlyOwner {
        require(!EnumerableMap.contains(brokerId2Balance, _brokerId), "brokerId already exist");
        EnumerableMap.set(brokerId2Balance, _brokerId, 0);
    }

    // add balance to brokerId
    function addBalance(bytes32 _brokerId, uint256 _balance) public onlyOwner {
        require(EnumerableMap.contains(brokerId2Balance, _brokerId), "brokerId not exist");
        uint256 balance = EnumerableMap.get(brokerId2Balance, _brokerId);
        EnumerableMap.set(brokerId2Balance, _brokerId, balance + _balance);
    }

    // get brokerId List. O(n)
    function getBrokerIdList() public view returns (bytes32[] memory) {
        uint256 length = brokerId2Balance.length();
        bytes32[] memory brokerIdList = new bytes32[](length);
        for (uint256 i = 0; i < length; i++) {
            uint256 _value;
            (brokerIdList[i], _value) = EnumerableMap.at(brokerId2Balance, i);
        }
        return brokerIdList;
    }
}

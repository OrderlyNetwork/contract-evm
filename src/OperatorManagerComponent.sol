// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./interface/IOperatorManagerComponent.sol";
import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

/**
 * OperatorManagerComponent is an component which can only be called by operatorManager (setter)
 */
abstract contract OperatorManagerComponent is IOperatorManagerComponent, OwnableUpgradeable {
    // OperatorManager address
    address public operatorManagerAddress;

    // only operatorManager
    modifier onlyOperatorManager() {
        if (msg.sender != operatorManagerAddress) revert OnlyOperatorManagerCanCall();
        _;
    }

    // set operatorManagerAddress
    function setOperatorManagerAddress(address _operatorManagerAddress) public override onlyOwner {
        operatorManagerAddress = _operatorManagerAddress;
    }
}

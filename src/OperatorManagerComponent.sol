// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./interface/IOperatorManagerComponent.sol";
import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

/// @title A component of OperatorManager
/// @author Orderly_Rubick
/// @notice OperatorManagerComponent is an component which can only be called by operatorManager (setter)
abstract contract OperatorManagerComponent is IOperatorManagerComponent, OwnableUpgradeable {
    // OperatorManager address
    address public operatorManagerAddress;

    function initialize() external virtual override initializer {
        __Ownable_init();
    }

    /// @notice only operatorManager
    modifier onlyOperatorManager() {
        if (msg.sender != operatorManagerAddress) revert OnlyOperatorManagerCanCall();
        _;
    }

    /// @notice set operatorManagerAddress
    function setOperatorManagerAddress(address _operatorManagerAddress) public override onlyOwner {
        if (_operatorManagerAddress == address(0)) revert OperatorManagerAddressZero();
        emit ChangeOperatorManager(operatorManagerAddress, _operatorManagerAddress);
        operatorManagerAddress = _operatorManagerAddress;
    }
}

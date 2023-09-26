// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

interface IOperatorManagerComponent {
    error OnlyOperatorManagerCanCall();
    error OperatorManagerAddressZero();

    event ChangeOperatorManager(address oldAddress, address newAddress);

    function initialize() external;

    // set operatorManagerAddress
    function setOperatorManagerAddress(address _operatorManagerAddress) external;
}

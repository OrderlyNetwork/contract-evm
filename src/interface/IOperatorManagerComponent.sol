// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./error/IError.sol";

interface IOperatorManagerComponent is IError {
    event ChangeOperatorManager(address oldAddress, address newAddress);

    function initialize() external;

    // set operatorManagerAddress
    function setOperatorManagerAddress(address _operatorManagerAddress) external;
}

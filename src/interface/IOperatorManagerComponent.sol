// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

interface IOperatorManagerComponent {
    error OnlyOperatorManagerCanCall();

    // set ledgerAddress
    function setOperatorManagerAddress(address _ledgerAddress) external;
}

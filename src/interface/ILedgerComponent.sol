// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./error/IError.sol";

interface ILedgerComponent is IError {
    event ChangeLedger(address oldAddress, address newAddress);

    function initialize() external;

    // set ledgerAddress
    function setLedgerAddress(address _ledgerAddress) external;
}

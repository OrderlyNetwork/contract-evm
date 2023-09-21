// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

interface ILedgerComponent {
    error OnlyLedgerCanCall();
    error LedgerAddressZero();

    event ChangeLedger(address oldAddress, address newAddress);

    // set ledgerAddress
    function setLedgerAddress(address _ledgerAddress) external;
}

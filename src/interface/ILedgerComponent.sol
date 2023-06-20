// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

interface ILedgerComponent {
    error OnlyLedgerCanCall();

    // set ledgerAddress
    function setLedgerAddress(address _ledgerAddress) external;
}

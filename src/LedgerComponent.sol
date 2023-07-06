// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./interface/ILedgerComponent.sol";
import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

/**
 * LedgerComponent is an component which can only be called by ledger (setter)
 */
abstract contract LedgerComponent is ILedgerComponent, OwnableUpgradeable {
    // Ledger address
    address public ledgerAddress;

    // only ledger
    modifier onlyLedger() {
        if (msg.sender != ledgerAddress) revert OnlyLedgerCanCall();
        _;
    }

    // set ledgerAddress
    function setLedgerAddress(address _ledgerAddress) public override onlyOwner {
        ledgerAddress = _ledgerAddress;
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./interface/ILedgerComponent.sol";
import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

/// @title A component of Ledger
/// @author Orderly_Rubick
/// @notice LedgerComponent is an component which can only be called by ledger (setter)
abstract contract LedgerComponent is ILedgerComponent, OwnableUpgradeable {
    // Ledger address
    address public ledgerAddress;

    function initialize() external virtual override initializer {
        __Ownable_init();
    }

    /// @notice only ledger
    modifier onlyLedger() {
        if (msg.sender != ledgerAddress) revert OnlyLedgerCanCall();
        _;
    }

    /// @notice set ledgerAddress
    function setLedgerAddress(address _ledgerAddress) public override onlyOwner {
        if (_ledgerAddress == address(0)) revert LedgerAddressZero();
        emit ChangeLedger(ledgerAddress, _ledgerAddress);
        ledgerAddress = _ledgerAddress;
    }
}

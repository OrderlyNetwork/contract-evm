// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./ILedgerError.sol";
import "./IVaultManagerError.sol";

// all error should be defined here, because OperatorManager need an omni error interface
interface IError is ILedgerError, IVaultManagerError {}

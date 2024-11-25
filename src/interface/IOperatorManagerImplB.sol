// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types/EventTypes.sol";
import "./error/IError.sol";
import "./IOperatorManagerEvent.sol";

interface IOperatorManagerImplB is IError, IOperatorManagerEvent {
    // operator call event upload
    function eventUpload(EventTypes.EventUpload calldata data) external;
}

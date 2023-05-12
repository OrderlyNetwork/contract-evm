// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types/OperatorTypes.sol";

interface IOperatorManager {
    function operatorExecuteAction(OperatorTypes.OperatorActionData actionData, bytes calldata action) external;
}

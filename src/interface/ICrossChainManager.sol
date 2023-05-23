// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types/OperatorTypes.sol";

interface ICrossChainManager {
    function crossChainOperatorExecuteAction(
        OperatorTypes.CrossChainOperatorActionData actionData,
        bytes calldata action
    ) external;
}

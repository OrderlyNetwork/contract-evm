// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types/OperatorTypes.sol";
import "../library/types/CrossChainMessageTypes.sol";

interface ICrossChainManager {
    // @deprecated TODO should be removed
    function crossChainOperatorExecuteAction(
        OperatorTypes.CrossChainOperatorActionData actionData,
        bytes calldata action
    ) external;

    // cross chain call deposit
    function deposit(CrossChainMessageTypes.MessageV1 calldata message) external;
}

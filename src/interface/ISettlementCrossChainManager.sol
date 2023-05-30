// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types/OperatorTypes.sol";
import "../library/types/PerpTypes.sol";
import "../crossChain/utils/OrderlyCrossChainMessage.sol";

interface ISettlementCrossChainManager {
    // cross chain call deposit
    function deposit(
        OrderlyCrossChainMessage.MessageV1 memory message
    ) external;

    // cross chain withdraw
    function withdraw(PerpTypes.WithdrawData calldata data) external;
}

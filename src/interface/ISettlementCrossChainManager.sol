// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types/OperatorTypes.sol";
import "../library/types/AccountTypes.sol";
import "../crossChain/utils/OrderlyCrossChainMessage.sol";
import "../crossChain/interface/IOrderlyCrossChain.sol";

interface ISettlementCrossChainManager {
    // cross chain call deposit
    function deposit(
        OrderlyCrossChainMessage.MessageV1 calldata message
    ) external;

    // cross chain withdraw
    function withdraw(AccountTypes.AccountWithdraw calldata data) external;
}

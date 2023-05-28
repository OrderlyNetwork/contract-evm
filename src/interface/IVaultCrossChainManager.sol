// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../crossChain/utils/OrderlyCrossChainMessage.sol";
import "../library/types/AccountTypes.sol";

interface IVaultCrossChainManager {
    function withdraw(
        OrderlyCrossChainMessage.MessageV1 calldata message
    ) external;

    function deposit(AccountTypes.AccountDeposit calldata data) external;
}

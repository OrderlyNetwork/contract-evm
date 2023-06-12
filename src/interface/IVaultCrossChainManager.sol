// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "crosschain/utils/OrderlyCrossChainMessage.sol";
import "../library/types/AccountTypes.sol";
import "../library/types/VaultTypes.sol";

interface IVaultCrossChainManager {
    function withdraw(
        OrderlyCrossChainMessage.MessageV1 memory message
    ) external;

    function deposit(VaultTypes.VaultDeposit memory data) external;
    function withdraw(VaultTypes.VaultWithdraw memory data) external;
}

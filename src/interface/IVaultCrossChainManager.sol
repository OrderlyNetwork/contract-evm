// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "crosschain/utils/OrderlyCrossChainMessage.sol";
import "../library/types/AccountTypes.sol";
import "../library/types/VaultTypes.sol";

interface IVaultCrossChainManager {
    // function withdraw(VaultTypes.VaultWithdraw memory withdraw) external;

    function deposit(VaultTypes.VaultDeposit memory data) external;
}

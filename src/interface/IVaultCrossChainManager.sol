// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types/CrossChainMessageTypes.sol";

interface IVaultCrossChainManager {
    function withdraw(CrossChainMessageTypes.MessageV1 calldata message) external;
}

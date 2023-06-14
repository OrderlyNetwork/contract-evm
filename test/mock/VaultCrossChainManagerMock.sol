// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../../src/interface/IVaultCrossChainManager.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "crosschain/interface/IOrderlyCrossChain.sol";

contract VaultCrossChainManagerMock is IOrderlyCrossChainReceiver, IVaultCrossChainManager, Ownable {
    function receiveMessage(bytes memory payload, uint256 srcChainId, uint256 dstChainId) external override {}

    function withdraw(OrderlyCrossChainMessage.MessageV1 memory message) external override {}

    function deposit(VaultTypes.VaultDeposit memory data) external override {}

    function withdraw(VaultTypes.VaultWithdraw memory data) external override {}
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../../src/interface/ILedgerCrossChainManager.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "crosschain/interface/IOrderlyCrossChain.sol";

contract LedgerCrossChainManagerMock is IOrderlyCrossChainReceiver, ILedgerCrossChainManager, Ownable {
    function receiveMessage(bytes memory payload, uint256 srcChainId, uint256 dstChainId) external override {}

    function deposit(OrderlyCrossChainMessage.MessageV1 memory message) external override {}

    function withdraw(EventTypes.WithdrawData calldata data) external override {}

    function withdrawFinish(OrderlyCrossChainMessage.MessageV1 memory message) external override {}

    function setLedger(address _ledger) external override {}

    function setOperatorManager(address _operatorManager) external override {}

    function setCrossChainRelay(address _crossChainRelay) external override {}
}

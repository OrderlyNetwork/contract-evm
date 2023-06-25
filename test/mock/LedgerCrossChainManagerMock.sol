// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../../src/interface/ILedgerCrossChainManager.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "crosschain/interface/IOrderlyCrossChain.sol";
import "../../src/interface/ILedger.sol";

contract LedgerCrossChainManagerMock is IOrderlyCrossChainReceiver, ILedgerCrossChainManager, Ownable {
    ILedger public ledger;

    function receiveMessage(OrderlyCrossChainMessage.MessageV1 memory message, bytes memory payload)
        external
        override
    {}

    function withdraw(EventTypes.WithdrawData calldata data) external override {}

    function setLedger(address _ledger) external override {
        ledger = ILedger(_ledger);
    }

    function setOperatorManager(address _operatorManager) external override {}

    function setCrossChainRelay(address _crossChainRelay) external override {}

    function withdrawFinishMock(AccountTypes.AccountWithdraw memory message) external {
        ledger.accountWithDrawFinish(message);
    }
}

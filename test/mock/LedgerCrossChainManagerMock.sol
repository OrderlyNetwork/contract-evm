// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../../src/interface/ILedgerCrossChainManager.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "../../src/interface/ILedger.sol";

contract LedgerCrossChainManagerMock is ILedgerCrossChainManager, Ownable {
    ILedger public ledger;

    function withdraw(EventTypes.WithdrawData calldata data) external override {}

    function setLedger(address _ledger) external override {
        ledger = ILedger(_ledger);
    }

    function setOperatorManager(address _operatorManager) external override {}

    function setCrossChainRelay(address _crossChainRelay) external override {}

    function withdrawFinishMock(AccountTypes.AccountWithdraw memory message) external {
        ledger.accountWithDrawFinish(message);
    }

    function burn(RebalanceTypes.RebalanceBurnCCData memory data) external override {}
    function mint(RebalanceTypes.RebalanceMintCCData memory data) external override {}
}

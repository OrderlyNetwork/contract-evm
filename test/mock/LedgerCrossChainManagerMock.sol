// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../../src/interface/ILedgerCrossChainManager.sol";
import "../mock/VaultCrossChainManagerMock.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "../../src/interface/ILedger.sol";
import "../../src/library/types/VaultTypes.sol";

contract LedgerCrossChainManagerMock is ILedgerCrossChainManager, Ownable {
    ILedger public ledger;
    VaultCrossChainManagerMock public vaultCCManagerMock;
    bool public calledwithdraw;

    function setVaultCCManagerMock(address _vaultCCManagerMock) external onlyOwner {
        vaultCCManagerMock = VaultCrossChainManagerMock(_vaultCCManagerMock);
    }

    function withdraw(EventTypes.WithdrawData calldata data) external override {
        require(data.tokenAmount >= 0, "Amount must be greater than zero.");
        calledwithdraw = true;

        // call VaultCCManagerMock
        if (data.withdrawNonce >= 0) {
            VaultTypes.VaultWithdraw memory withdrawData = VaultTypes.VaultWithdraw({
                accountId: data.accountId,
                sender: data.sender,
                receiver: data.receiver,
                brokerHash: keccak256(abi.encodePacked(data.brokerId)),
                tokenHash: keccak256(abi.encodePacked(data.tokenSymbol)),
                tokenAmount: data.tokenAmount,
                fee: 0,
                withdrawNonce: 0
            });

            vaultCCManagerMock.accountWithdrawMock(withdrawData);
        }
    }

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

    function accountDepositMock(AccountTypes.AccountDeposit memory data) external {
        ledger.accountDeposit(data);
    }
}

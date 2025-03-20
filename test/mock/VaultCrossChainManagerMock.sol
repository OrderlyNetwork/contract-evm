// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../../src/interface/IVaultCrossChainManager.sol";
import "../../src/interface/IVault.sol";
import "../mock/LedgerCrossChainManagerMock.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract VaultCrossChainManagerMock is IVaultCrossChainManager, Ownable {
    IVault public vault;
    LedgerCrossChainManagerMock public ledgerCCManagerMock;
    bool public calledDeposit;
    bool public calledDepositWithFeeRefund;

    function setVault(address _vault) external override {
        vault = IVault(_vault);
    }

    function getDepositFee(VaultTypes.VaultDeposit memory data) external view override returns (uint256) {}

    function setLedgerCCManagerMock(address _ledgerCCManagerMock) external onlyOwner {
        require(_ledgerCCManagerMock != address(0), "Invalid address: zero address provided");
        ledgerCCManagerMock = LedgerCrossChainManagerMock(_ledgerCCManagerMock);
    }

    function deposit(VaultTypes.VaultDeposit memory data) external override {
        require(data.tokenAmount >= 0, "Amount must be greater than zero.");
        calledDeposit = true;

        // call LedgerCCManagerMock

        AccountTypes.AccountDeposit memory depositData = AccountTypes.AccountDeposit({
            accountId: data.accountId,
            brokerHash: data.brokerHash,
            userAddress: data.userAddress,
            tokenHash: data.tokenHash,
            tokenAmount: data.tokenAmount,
            srcChainId: 986532,
            srcChainDepositNonce: 1
        });

        ledgerCCManagerMock.accountDepositMock(depositData);
    }

    function burnFinish(RebalanceTypes.RebalanceBurnCCFinishData memory data) external override {}

    function mintFinish(RebalanceTypes.RebalanceMintCCFinishData memory data) external override {}

    function withdraw(VaultTypes.VaultWithdraw memory data) external override {}

    function setCrossChainRelay(address _crossChainRelay) external override {}

    function depositWithFee(VaultTypes.VaultDeposit memory _data) external payable override {}

    function depositWithFeeRefund(address refundReceiver, VaultTypes.VaultDeposit memory _data)
        external
        payable
        override
    {
        require(refundReceiver != address(0), "Invalid address: zero address provided");
        require(_data.tokenAmount >= 0, "Amount must be greater than zero.");
        calledDepositWithFeeRefund = true;
    }

    function accountWithdrawMock(VaultTypes.VaultWithdraw memory data) external {
        vault.withdraw(data);
    }
}

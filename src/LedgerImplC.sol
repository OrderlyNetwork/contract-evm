// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.26;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import "./dataLayout/LedgerDataLayout.sol";
import "./interface/ILedger.sol";
import "./interface/ILedgerImplC.sol";
import "./interface/ILedgerCrossChainManager.sol";
import "./interface/ILedgerCrossChainManagerV2.sol";
import "./library/Utils.sol";
import "./library/Signature.sol";
import "./library/typesHelper/SafeCastHelper.sol";


/// @title Ledger contract, implementation part C contract, for resolve EIP170 limit
/// @notice This contract is designed for Solana connection
/// @author Orderly_Rubick
contract LedgerImplC is ILedgerImplC, OwnableUpgradeable, LedgerDataLayout {
    using AccountTypeHelper for AccountTypes.Account;
    using SafeCast for uint256;
    using SafeCastHelper for uint128;

    constructor() {
        _disableInitializers();
    }

    function accountDepositSol(AccountTypes.AccountDepositSol calldata data) external override {
        // validate data first
        if (!vaultManager.getAllowedBroker(data.brokerHash)) revert BrokerNotAllowed();
        if (!vaultManager.getAllowedChainToken(data.tokenHash, data.srcChainId)) {
            revert TokenNotAllowed(data.tokenHash, data.srcChainId);
        }
        if (!Utils.validateAccountId(data.accountId, data.brokerHash, data.pubkey)) revert AccountIdInvalid();

        // a not registerd account can still deposit, because of the consistency
        AccountTypes.Account storage account = userLedger[data.accountId];
        if (account.solAccountPubKey == bytes32(0)) {
            // register account first
            account.solAccountPubKey = data.pubkey;
            account.brokerHash = data.brokerHash;
            // emit register event
            emit AccountRegister(data.accountId, data.brokerHash, data.pubkey);
        }
        account.addBalance(data.tokenHash, data.tokenAmount);
        vaultManager.addBalance(data.tokenHash, data.srcChainId, data.tokenAmount);
        uint64 tmpGlobalEventId = _newGlobalEventId(); // gas saving
        account.lastDepositEventId = tmpGlobalEventId;
        account.lastDepositSrcChainId = data.srcChainId.toUint64();
        account.lastDepositSrcChainNonce = data.srcChainDepositNonce;
        // emit deposit event
        emit AccountDepositSol(
            data.accountId,
            _newGlobalDepositId(),
            tmpGlobalEventId,
            data.pubkey,
            data.tokenHash,
            data.tokenAmount,
            data.srcChainId,
            data.srcChainDepositNonce,
            data.brokerHash
        );
    }

    function executeWithdrawSolAction(EventTypes.WithdrawDataSol calldata withdraw, uint64 eventId) external override {
        bytes32 brokerHash = Utils.calculateStringHash(withdraw.brokerId);
        bytes32 tokenHash = Utils.calculateStringHash(withdraw.tokenSymbol);
        if (!vaultManager.getAllowedBroker(brokerHash)) revert BrokerNotAllowed();
        if (!vaultManager.getAllowedChainToken(tokenHash, withdraw.chainId)) {
            revert TokenNotAllowed(tokenHash, withdraw.chainId);
        }
        if (!Utils.validateAccountId(withdraw.accountId, brokerHash, withdraw.sender)) revert AccountIdInvalid();
        AccountTypes.Account storage account = userLedger[withdraw.accountId];
        uint8 state = 0;
        {
            // avoid stack too deep
            uint128 maxWithdrawFee = vaultManager.getMaxWithdrawFee(tokenHash);
            // https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/326402549/Withdraw+Error+Code
            /// @notice similar to `LedgerImplA.executeWithdrawAction()`
            if (account.lastWithdrawNonce >= withdraw.withdrawNonce) {
                // require withdraw nonce inc
                state = 101;
            } else if (account.balances[tokenHash] < withdraw.tokenAmount.toInt128()) {
                // require balance enough
                revert WithdrawBalanceNotEnough(account.balances[tokenHash], withdraw.tokenAmount);
            } else if (account.balances[tokenHash] - escrowBalances[withdraw.accountId][tokenHash].toInt128() < withdraw.tokenAmount.toInt128()) {
                /// @dev Check available balance (balance - escrow) to prevent withdrawal of in-flight transfer funds
                state = 9;
            } else if (vaultManager.getBalance(tokenHash, withdraw.chainId) < withdraw.tokenAmount - withdraw.fee) {
                // require chain has enough balance
                revert WithdrawVaultBalanceNotEnough(
                    vaultManager.getBalance(tokenHash, withdraw.chainId), withdraw.tokenAmount - withdraw.fee
                );
            } else if (!Signature.verifyWithdrawSol(withdraw)) {
                // require signature verify
                state = 4;
            } else if (maxWithdrawFee > 0 && maxWithdrawFee < withdraw.fee) {
                // require fee not exceed maxWithdrawFee
                revert WithdrawFeeTooLarge(maxWithdrawFee, withdraw.fee);
            } else if (withdraw.receiver == bytes32(0)) {
                // require receiver not zero address
                revert WithdrawToAddressZero();
            }
        }
        // check all assert, should not change any status
        if (state != 0) {
            emit AccountWithdrawSolFail(
                withdraw.accountId,
                withdraw.withdrawNonce,
                _newGlobalEventId(),
                brokerHash,
                withdraw.sender,
                withdraw.receiver,
                withdraw.chainId,
                tokenHash,
                withdraw.tokenAmount,
                withdraw.fee,
                state
            );
            return;
        }
        // update status, should never fail
        // frozen balance
        // account should frozen `tokenAmount`, and vault should frozen `tokenAmount - fee`, because vault will payout `tokenAmount - fee`
        account.frozenBalance(withdraw.withdrawNonce, tokenHash, withdraw.tokenAmount);
        vaultManager.frozenBalance(tokenHash, withdraw.chainId, withdraw.tokenAmount - withdraw.fee);
        /// @dev sol does not have withdrawFinish action, so we can finish it in one action
        // finish frozen balance
        account.finishFrozenBalance(withdraw.withdrawNonce, tokenHash, withdraw.tokenAmount);
        vaultManager.finishFrozenBalance(tokenHash, withdraw.chainId, withdraw.tokenAmount - withdraw.fee);
        // withdraw fee
        if (withdraw.fee > 0) {
            // gas saving if no fee
            bytes32 feeCollectorAccountId =
                feeManager.getFeeCollector(IFeeManager.FeeCollectorType.WithdrawFeeCollector);
            AccountTypes.Account storage feeCollectorAccount = userLedger[feeCollectorAccountId];
            feeCollectorAccount.addBalance(tokenHash, withdraw.fee);
        }
        account.lastEngineEventId = eventId;
        // emit withdraw approve event
        emit AccountWithdrawSolApprove(
            withdraw.accountId,
            withdraw.withdrawNonce,
            _newGlobalEventId(),
            brokerHash,
            withdraw.sender,
            withdraw.receiver,
            withdraw.chainId,
            tokenHash,
            withdraw.tokenAmount,
            withdraw.fee
        );
        // send cross-chain tx
        ILedgerCrossChainManagerV2(crossChainManagerV2Address).withdraw(withdraw);
    }

    function executeBalanceTransfer(EventTypes.BalanceTransfer calldata balanceTransfer, uint64 eventId)
        external
        override
    {
        require(balanceTransfer.amount > 0, "ZERO_AMT");
        
        EventTypes.InternalTransferTrack storage transferTrack = transfers[balanceTransfer.transferId];
        
        // Initialize transfer track if this is the first event for this transfer
        if (transferTrack.side == EventTypes.TransferSide.None) {
            transferTrack.tokenHash = balanceTransfer.tokenHash;
            transferTrack.amount = balanceTransfer.amount;
        } else {
            // Validate that transfer parameters match
            require(
                transferTrack.tokenHash == balanceTransfer.tokenHash && 
                transferTrack.amount == balanceTransfer.amount,
                "PARAM_MISMATCH"
            );
        }
        
        if (balanceTransfer.isFromAccountId) {
            _applyDebit(balanceTransfer.fromAccountId, balanceTransfer.tokenHash, balanceTransfer.amount, transferTrack, eventId);
        } else {
            _applyCredit(balanceTransfer.toAccountId, balanceTransfer.tokenHash, balanceTransfer.amount, transferTrack, eventId);
        }
        
        // Emit balance transfer event for each processed event
        emit BalanceTransfer(
            _newGlobalEventId(),
            balanceTransfer.transferId,
            balanceTransfer.fromAccountId,
            balanceTransfer.toAccountId,
            balanceTransfer.amount,
            balanceTransfer.tokenHash,
            balanceTransfer.isFromAccountId,
            balanceTransfer.transferType
        );
        
        if (transferTrack.side == EventTypes.TransferSide.Both) {
            _finalizeTransfer(balanceTransfer.transferId, balanceTransfer.toAccountId, balanceTransfer.tokenHash, balanceTransfer.amount);
        }
    }
    
    function _applyDebit(
        bytes32 fromAccountId,
        bytes32 tokenHash,
        uint128 amount,
        EventTypes.InternalTransferTrack storage transferTrack,
        uint64 eventId
    ) private {
        require(
            transferTrack.side != EventTypes.TransferSide.Debit && 
            transferTrack.side != EventTypes.TransferSide.Both,
            "DEBIT_DUP"
        );
        
        AccountTypes.Account storage fromAccount = userLedger[fromAccountId];
        fromAccount.subBalance(tokenHash, amount);
        fromAccount.lastEngineEventId = eventId;
        
        transferTrack.side = (transferTrack.side == EventTypes.TransferSide.None)
            ? EventTypes.TransferSide.Debit
            : EventTypes.TransferSide.Both;
    }
    
    function _applyCredit(
        bytes32 toAccountId,
        bytes32 tokenHash,
        uint128 amount,
        EventTypes.InternalTransferTrack storage transferTrack,
        uint64 eventId
    ) private {
        require(
            transferTrack.side != EventTypes.TransferSide.Credit && 
            transferTrack.side != EventTypes.TransferSide.Both,
            "CREDIT_DUP"
        );
        
        AccountTypes.Account storage toAccount = userLedger[toAccountId];
        escrowBalances[toAccountId][tokenHash] += amount;
        toAccount.addBalance(tokenHash, amount);
        toAccount.lastEngineEventId = eventId;
        
        transferTrack.side = (transferTrack.side == EventTypes.TransferSide.None)
            ? EventTypes.TransferSide.Credit
            : EventTypes.TransferSide.Both;
    }
    
    function _finalizeTransfer(
        uint256 transferId,
        bytes32 toAccountId,
        bytes32 tokenHash,
        uint128 amount
    ) private {
        uint128 escrowBalance = escrowBalances[toAccountId][tokenHash];
        require(escrowBalance >= amount, "ESCROW_INCONSISTENT");
        escrowBalances[toAccountId][tokenHash] = escrowBalance - amount;
        delete transfers[transferId];
        
        emit InternalTransferFinalised(
            _newGlobalEventId(),
            transferId,
            toAccountId,
            tokenHash,
            amount
        );
    }
    
    // ==================== Internal Functions ====================

    function _newGlobalEventId() internal returns (uint64) {
        return ++globalEventId;
    }

    function _newGlobalDepositId() internal returns (uint64) {
        return ++globalDepositId;
    }
}

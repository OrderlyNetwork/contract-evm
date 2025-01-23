// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import "./dataLayout/LedgerDataLayout.sol";
import "./interface/ILedger.sol";
import "./interface/ILedgerImplC.sol";
import "./interface/ILedgerCrossChainManager.sol";
import "./interface/ILedgerCrossChainManagerV2.sol";
import "./library/Utils.sol";
import "./library/Signature.sol";

/// @title Ledger contract, implementation part C contract, for resolve EIP170 limit
/// @notice This contract is designed for Solana connection
/// @author Orderly_Rubick
contract LedgerImplC is ILedgerImplC, OwnableUpgradeable, LedgerDataLayout {
    using AccountTypeHelper for AccountTypes.Account;
    using SafeCast for uint256;

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
            if (account.lastWithdrawNonce >= withdraw.withdrawNonce) {
                // require withdraw nonce inc
                state = 101;
            } else if (account.balances[tokenHash] < withdraw.tokenAmount) {
                // require balance enough
                revert WithdrawBalanceNotEnough(account.balances[tokenHash], withdraw.tokenAmount);
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

    function executeWithdraw2Contract(EventTypes.Withdraw2Contract calldata withdraw, uint64 eventId)
        external
        override
    {
        bytes32 brokerHash = withdraw.brokerHash;
        bytes32 tokenHash = withdraw.tokenHash;
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
            if (account.lastWithdrawNonce >= withdraw.withdrawNonce) {
                // require withdraw nonce inc
                state = 101;
            } else if (account.balances[tokenHash] < withdraw.tokenAmount) {
                // require balance enough
                revert WithdrawBalanceNotEnough(account.balances[tokenHash], withdraw.tokenAmount);
            } else if (vaultManager.getBalance(tokenHash, withdraw.chainId) < withdraw.tokenAmount - withdraw.fee) {
                // require chain has enough balance
                revert WithdrawVaultBalanceNotEnough(
                    vaultManager.getBalance(tokenHash, withdraw.chainId), withdraw.tokenAmount - withdraw.fee
                );
            } else if (maxWithdrawFee > 0 && maxWithdrawFee < withdraw.fee) {
                // require fee not exceed maxWithdrawFee
                revert WithdrawFeeTooLarge(maxWithdrawFee, withdraw.fee);
            }
        }
        // check all assert, should not change any status
        if (state != 0) {
            emit AccountWithdrawFail(
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
        account.frozenBalance(withdraw.withdrawNonce, withdraw.tokenHash, withdraw.tokenAmount);
        vaultManager.frozenBalance(withdraw.tokenHash, withdraw.chainId, withdraw.tokenAmount - withdraw.fee);
        account.lastEngineEventId = eventId;
        // emit withdraw approve event
        emit AccountWithdrawApprove(
            withdraw.accountId,
            withdraw.withdrawNonce,
            _newGlobalEventId(),
            withdraw.brokerHash,
            withdraw.sender,
            withdraw.receiver,
            withdraw.chainId,
            withdraw.tokenHash,
            withdraw.tokenAmount,
            withdraw.fee
        );
        // send cross-chain tx
        ILedgerCrossChainManager(crossChainManagerAddress).withdraw2Contract(withdraw);
    }

    // internal functions

    function _newGlobalEventId() internal returns (uint64) {
        return ++globalEventId;
    }

    function _newGlobalDepositId() internal returns (uint64) {
        return ++globalDepositId;
    }
}

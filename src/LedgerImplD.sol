// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.26;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import "./dataLayout/LedgerDataLayout.sol";
import "./interface/ILedgerImplD.sol";
import "./interface/ILedgerCrossChainManager.sol";
import "./library/Utils.sol";
import "./library/typesHelper/AccountTypeHelper.sol";
import "./library/typesHelper/SafeCastHelper.sol";
import "./library/Version.sol";

/// @title Ledger contract, implementation part D contract, for resolve EIP170 limit
/// @notice This contract is designed for contract withdraw
/// @author Orderly_Zibin
contract LedgerImplD is ILedgerImplD, OwnableUpgradeable, LedgerDataLayout, Version {
    using AccountTypeHelper for AccountTypes.Account;
    using SafeCast for uint256;
    using SafeCastHelper for uint128;

    constructor() {
        _disableInitializers();
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
        {
            if (!Utils.validateExtendedAccountId(withdraw.receiver, withdraw.accountId, brokerHash, withdraw.sender)) {
                revert AccountIdInvalid();
            }
            if (withdraw.receiver == address(0)) revert WithdrawToAddressZero();

            if (withdraw.vaultType == EventTypes.VaultEnum.Ceffu) {
                if (withdraw.receiver != idToPrimeWallet[withdraw.accountId]) {
                    revert InvalidPrimeWallet();
                }
            } else if (withdraw.vaultType == EventTypes.VaultEnum.ProtocolVault) {
                if (!isValidVault[withdraw.receiver]) {
                    revert InvalidVault();
                }
            } else {
                revert NotImplemented();
            }
        }
        AccountTypes.Account storage account = userLedger[withdraw.accountId];
        uint8 state = 0;
        {
            uint128 maxWithdrawFee = vaultManager.getMaxWithdrawFee(tokenHash);
            if (account.lastWithdrawNonce >= withdraw.withdrawNonce) {
                state = 101;
            } else if (account.balances[tokenHash] < withdraw.tokenAmount.toInt128()) {
                revert WithdrawBalanceNotEnough(account.balances[tokenHash], withdraw.tokenAmount);
            } else if (vaultManager.getBalance(tokenHash, withdraw.chainId) < withdraw.tokenAmount - withdraw.fee) {
                revert WithdrawVaultBalanceNotEnough(
                    vaultManager.getBalance(tokenHash, withdraw.chainId), withdraw.tokenAmount - withdraw.fee
                );
            } else if (maxWithdrawFee > 0 && maxWithdrawFee < withdraw.fee) {
                revert WithdrawFeeTooLarge(maxWithdrawFee, withdraw.fee);
            }
        }

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

        account.frozenBalance(withdraw.withdrawNonce, withdraw.tokenHash, withdraw.tokenAmount);
        vaultManager.frozenBalance(withdraw.tokenHash, withdraw.chainId, withdraw.tokenAmount - withdraw.fee);
        account.lastEngineEventId = eventId;

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

        ILedgerCrossChainManager(crossChainManagerAddress).withdraw2Contract(withdraw);
    }

    function executeSwapResultUpload(EventTypes.SwapResult calldata swapResultUpload, uint64 eventId)
        external
        override
    {
        AccountTypes.Account storage userAccount = userLedger[swapResultUpload.accountId];
        userAccount.applyDelta(swapResultUpload.buyTokenHash, swapResultUpload.buyQuantity);
        userAccount.applyDelta(swapResultUpload.sellTokenHash, swapResultUpload.sellQuantity);
        userAccount.lastEngineEventId = eventId;

        // if on-chain success, update the balance on the vault contract
        if (swapResultUpload.swapStatus == 1) {
            vaultManager.applyDeltaBalance(
                swapResultUpload.buyTokenHash, swapResultUpload.chainId, swapResultUpload.buyQuantity
            );
            vaultManager.applyDeltaBalance(
                swapResultUpload.sellTokenHash, swapResultUpload.chainId, swapResultUpload.sellQuantity
            );
        }

        emit SwapResultUploaded(
            _newGlobalEventId(),
            swapResultUpload.accountId,
            swapResultUpload.buyTokenHash,
            swapResultUpload.sellTokenHash,
            swapResultUpload.buyQuantity,
            swapResultUpload.sellQuantity,
            swapResultUpload.chainId,
            swapResultUpload.swapStatus
        );
    }

    function _newGlobalEventId() internal returns (uint64) {
        return ++globalEventId;
    }
}

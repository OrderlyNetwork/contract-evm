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

/// @title Ledger contract, implementation part D contract, for resolve EIP170 limit
/// @notice This contract is designed for contract withdraw
/// @author Orderly_Rubick
contract LedgerImplD is ILedgerImplD, OwnableUpgradeable, LedgerDataLayout {
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
            address protocolVault = vaultManager.getProtocolVaultAddress();

            if (!Utils.validateExtendedAccountId(protocolVault, withdraw.accountId, brokerHash, withdraw.sender)) {
                revert AccountIdInvalid();
            }
            if (withdraw.receiver == address(0)) revert WithdrawToAddressZero();

            if (withdraw.vaultType == EventTypes.VaultEnum.Ceffu) {
                if (withdraw.receiver != idToPrimeWallet[withdraw.accountId]) {
                    revert InvalidPrimeWallet();
                }
            } else if (withdraw.vaultType == EventTypes.VaultEnum.ProtocolVault) {
                if (withdraw.receiver != protocolVault) {
                    revert ProtocolVaultAddressMismatch(address(protocolVault), withdraw.receiver);
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

    function executeSwapResultUpload(EventTypes.SwapResult calldata swapResultUpload, uint64 eventId) external override {
        AccountTypes.Account storage userAccount = userLedger[swapResultUpload.accountId];
        userAccount.addBalance(swapResultUpload.buyTokenHash, swapResultUpload.buyQuantity.toUint128());
        userAccount.subBalance(swapResultUpload.sellTokenHash, swapResultUpload.sellQuantity.toUint128());
        userAccount.lastEngineEventId = eventId;

        emit SwapResultUploaded(
            _newGlobalEventId(),
            swapResultUpload.accountId,
            swapResultUpload.buyTokenHash,
            swapResultUpload.sellTokenHash,
            swapResultUpload.buyQuantity,
            swapResultUpload.sellQuantity
        );
    }

    function _newGlobalEventId() internal returns (uint64) {
        return ++globalEventId;
    }
}

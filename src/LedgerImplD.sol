// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.26;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import "./dataLayout/LedgerDataLayout.sol";
import "./interface/ILedgerImplD.sol";
import "./interface/ILedgerCrossChainManager.sol";
import "./interface/ILedgerCrossChainManagerV2.sol";
import "./library/Utils.sol";
import "./library/typesHelper/AccountTypeHelper.sol";
import "./library/typesHelper/SafeCastHelper.sol";

/// @title Ledger contract, implementation part D contract, for resolve EIP170 limit
/// @notice This contract is designed for contract withdraw
/// @author Orderly_Zibin
contract LedgerImplD is ILedgerImplD, OwnableUpgradeable, LedgerDataLayout {
    using AccountTypeHelper for AccountTypes.Account;
    using SafeCast for uint256;
    using SafeCastHelper for uint128;

    constructor() {
        _disableInitializers();
    }

    function executeWithdraw2Contract(EventTypes.Withdraw2Contract calldata withdraw, uint64 eventId) external override{
        _executeWithdraw2EVM(withdraw, eventId);
    }

    function executeWithdraw2ContractV2(EventTypes.Withdraw2ContractV2 calldata withdrawV2, uint64 eventId) external override{
        if (withdrawV2.receiverChainType == EventTypes.ChainType.EVM) {
            _executeWithdraw2EVM(_convertV2ToEvmWithdraw(withdrawV2), eventId);
            return;
        }

        if (withdrawV2.receiverChainType == EventTypes.ChainType.SOL) {
            _executeWithdraw2SOL(withdrawV2, eventId);
            return;
        }
        revert UnsupportChainType();
    }

    function executeSwapResultUpload(EventTypes.SwapResult calldata swapResultUpload, uint64 eventId) external override {
        AccountTypes.Account storage userAccount = userLedger[swapResultUpload.accountId];
        userAccount.applyDelta(
            swapResultUpload.buyTokenHash,
            swapResultUpload.buyQuantity
        );
        userAccount.applyDelta(
            swapResultUpload.sellTokenHash,
            swapResultUpload.sellQuantity
        );
        userAccount.lastEngineEventId = eventId;

        // if on-chain success, update the balance on the vault contract
        if (swapResultUpload.swapStatus == 1) {
            vaultManager.applyDeltaBalance(
                swapResultUpload.buyTokenHash,
                swapResultUpload.chainId,
                swapResultUpload.buyQuantity
            );
            vaultManager.applyDeltaBalance(
                swapResultUpload.sellTokenHash,
                swapResultUpload.chainId,
                swapResultUpload.sellQuantity
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

    /*//////////////////////////////////////////////////////////////
                            INTERNAL CORE
    //////////////////////////////////////////////////////////////*/

    function _executeWithdraw2EVM(EventTypes.Withdraw2Contract memory withdraw, uint64 eventId) internal {

        _checkTokenAndBroker(
            withdraw.tokenHash,
            withdraw.brokerHash,
            withdraw.chainId
        );

        _validateEvmReceiver(withdraw);

        AccountTypes.Account storage account =
            userLedger[withdraw.accountId];

        uint8 state = _checkWithdrawState(
            account,
            withdraw.accountId,
            withdraw.tokenHash,
            withdraw.chainId,
            withdraw.tokenAmount,
            withdraw.fee,
            withdraw.withdrawNonce
        );

        if (state != 0) {
            emit AccountWithdrawFail(
                withdraw.accountId,
                withdraw.withdrawNonce,
                _newGlobalEventId(),
                withdraw.brokerHash,
                withdraw.sender,
                withdraw.receiver,
                withdraw.chainId,
                withdraw.tokenHash,
                withdraw.tokenAmount,
                withdraw.fee,
                state
            );
            return;
        }

        _freezeWithdraw(
            account,
            withdraw.tokenHash,
            withdraw.chainId,
            withdraw.tokenAmount,
            withdraw.fee,
            withdraw.withdrawNonce
        );

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
    
    function _executeWithdraw2SOL(EventTypes.Withdraw2ContractV2 memory withdraw, uint64 eventId) internal {
        
        _checkTokenAndBroker(
            withdraw.tokenHash,
            withdraw.brokerHash,
            withdraw.chainId
        );

        _validateSolReceiver(withdraw);

        AccountTypes.Account storage account =
            userLedger[withdraw.accountId];

        uint8 state = _checkWithdrawState(
            account,
            withdraw.accountId,
            withdraw.tokenHash,
            withdraw.chainId,
            withdraw.tokenAmount,
            withdraw.fee,
            withdraw.withdrawNonce
        );

        if (state != 0) {
            emit AccountWithdrawSolFail(
                withdraw.accountId,
                withdraw.withdrawNonce,
                _newGlobalEventId(),
                withdraw.senderChainType,
                withdraw.receiverChainType,
                withdraw.brokerHash,
                withdraw.sender,
                withdraw.receiver,
                withdraw.chainId,
                withdraw.tokenHash,
                withdraw.tokenAmount,
                withdraw.fee,
                state
            );
            return;
        }

        _freezeWithdraw(
            account,
            withdraw.tokenHash,
            withdraw.chainId,
            withdraw.tokenAmount,
            withdraw.fee,
            withdraw.withdrawNonce
        );

        // SOL: no async finish callback
        _finishWithdrawImmediately(
            account,
            withdraw.tokenHash,
            withdraw.chainId,
            withdraw.tokenAmount,
            withdraw.fee,
            withdraw.withdrawNonce
        );

        account.lastEngineEventId = eventId;

        emit AccountWithdrawSolApprove(
            withdraw.accountId,
            withdraw.withdrawNonce,
            _newGlobalEventId(),
            withdraw.senderChainType,
            withdraw.receiverChainType,
            withdraw.brokerHash,
            withdraw.sender,
            withdraw.receiver,
            withdraw.chainId,
            withdraw.tokenHash,
            withdraw.tokenAmount,
            withdraw.fee
        );

        ILedgerCrossChainManagerV2(crossChainManagerV2Address).withdraw2ContractV2(withdraw);
    }

    /*//////////////////////////////////////////////////////////////
                            VALIDATION
    //////////////////////////////////////////////////////////////*/

    function _validateEvmReceiver(EventTypes.Withdraw2Contract memory withdraw) internal view {
        if (withdraw.receiver == address(0)) {
            revert WithdrawToAddressZero();
        }

        if (withdraw.vaultType == EventTypes.VaultEnum.Ceffu) {
            if (withdraw.receiver != idToPrimeWallet[withdraw.accountId]) revert InvalidPrimeWallet();
            return;
        }

        if (withdraw.vaultType == EventTypes.VaultEnum.ProtocolVault) {
            if (!Utils.validateExtendedAccountId(
                    withdraw.receiver,
                    withdraw.accountId,
                    withdraw.brokerHash,
                    withdraw.sender
                )
            ) revert AccountIdInvalid();

            if (!isValidVault[withdraw.receiver]) {
                revert InvalidVault();
            }
            return;
        }

        revert NotImplemented();
    }

    function _validateSolReceiver(EventTypes.Withdraw2ContractV2 memory withdraw) internal view {
        if (withdraw.receiver == bytes32(0)) {
            revert WithdrawToAddressZero();
        }

        // Only Ceffu vault type is supported for Solana withdrawals
        if ( withdraw.vaultType == EventTypes.VaultEnum.Ceffu) {
            if ( withdraw.receiver != idToSolanaPrimeWallet[withdraw.accountId]) revert InvalidPrimeWallet();
            return;
        }

        revert NotImplemented(); 
    }

    function _checkWithdrawState(
        AccountTypes.Account storage account,
        bytes32 accountId,
        bytes32 tokenHash,
        uint256 chainId,
        uint128 tokenAmount,
        uint128 fee,
        uint64 withdrawNonce
    ) internal view returns (uint8) {
        if (account.lastWithdrawNonce >= withdrawNonce) {
            return 101;
        }

        int128 balance = account.balances[tokenHash];
        if (balance < tokenAmount.toInt128()) {
            revert WithdrawBalanceNotEnough(balance, tokenAmount);
        }

        int128 available = balance - escrowBalances[accountId][tokenHash].toInt128();
        /// @dev Check available balance (balance - escrow) to prevent withdrawal of in-flight transfer funds
        if (available < tokenAmount.toInt128()) {
            return 9;
        }

        uint128 vaultBalance = vaultManager.getBalance(tokenHash, chainId);
        if (vaultBalance < tokenAmount - fee) {
            revert WithdrawVaultBalanceNotEnough(vaultBalance, tokenAmount - fee);
        }

        uint128 maxFee = vaultManager.getMaxWithdrawFee(tokenHash);
        if (maxFee > 0 && fee > maxFee) revert WithdrawFeeTooLarge(maxFee, fee);
    
        return 0;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE UPDATE
    //////////////////////////////////////////////////////////////*/

    function _freezeWithdraw(
        AccountTypes.Account storage account,
        bytes32 tokenHash,
        uint256 chainId,
        uint128 tokenAmount,
        uint128 fee,
        uint64 withdrawNonce
    ) internal {
        account.frozenBalance(
            withdrawNonce,
            tokenHash,
            tokenAmount
        );

        vaultManager.frozenBalance(
            tokenHash,
            chainId,
            tokenAmount - fee
        );
    }

    function _finishWithdrawImmediately(
        AccountTypes.Account storage account,
        bytes32 tokenHash,
        uint256 chainId,
        uint128 tokenAmount,
        uint128 fee,
        uint64 withdrawNonce
    ) internal {
        account.finishFrozenBalance(
            withdrawNonce,
            tokenHash,
            tokenAmount
        );

        vaultManager.finishFrozenBalance(
            tokenHash,
            chainId,
            tokenAmount - fee
        );

        if (fee > 0) {
            bytes32 feeCollectorId = feeManager.getFeeCollector(IFeeManager.FeeCollectorType.WithdrawFeeCollector);
            userLedger[feeCollectorId].addBalance(tokenHash, fee);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    function _convertV2ToEvmWithdraw(EventTypes.Withdraw2ContractV2 memory v2) internal pure returns (EventTypes.Withdraw2Contract memory) {
        return EventTypes.Withdraw2Contract({
            tokenAmount: v2.tokenAmount,
            fee: v2.fee,
            chainId: v2.chainId,
            accountId: v2.accountId,
            vaultType: v2.vaultType,
            sender: Utils.bytes32ToAddress(v2.sender),
            withdrawNonce: v2.withdrawNonce,
            receiver: Utils.bytes32ToAddress(v2.receiver),
            timestamp: v2.timestamp,
            brokerHash: v2.brokerHash,
            tokenHash: v2.tokenHash,
            clientId: v2.clientId
        });
    }

    function _checkTokenAndBroker(bytes32 tokenHash, bytes32 brokerHash, uint256 chainId) internal view {
        if (!vaultManager.getAllowedBroker(brokerHash)) revert BrokerNotAllowed();
        if (!vaultManager.getAllowedChainToken(tokenHash, chainId)) revert TokenNotAllowed(tokenHash, chainId);
    }

    function _newGlobalEventId() internal returns (uint64) {
        return ++globalEventId;
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

// All errors should be defined here
interface IError {
    // Common Error
    error AddressZero();
    error Bytes32Zero();
    error DelegatecallFail();

    // LedgerComponent Error
    error OnlyLedgerCanCall();
    error LedgerAddressZero();

    // OperatorManager Error
    error OnlyOperatorManagerCanCall();
    error OperatorManagerAddressZero();

    // Ledger Error
    error OnlyOperatorCanCall();
    error OnlyCrossChainManagerCanCall();
    error TotalSettleAmountNotMatch(int128 amount);
    error BalanceNotEnough(uint128 balance, int128 amount);
    error InsuranceTransferToSelf();
    error InsuranceTransferAmountInvalid(uint128 balance, uint128 insuranceTransferAmount, int128 settledAmount);
    error UserPerpPositionQtyZero(bytes32 accountId, bytes32 symbolHash);
    error InsurancePositionQtyInvalid(int128 adlPositionQtyTransfer, int128 userPositionQty);
    error AccountIdInvalid();
    error TokenNotAllowed(bytes32 tokenHash, uint256 chainId);
    error BrokerNotAllowed();
    error SymbolNotAllowed();
    error DelegateSignerNotMatch(bytes32 accountId, address savedSginer, address givenSigner);
    error DelegateChainIdNotMatch(bytes32 accountId, uint256 savedChainId, uint256 givenChainId);
    error DelegateReceiverNotMatch(address receiver, address delegateContract);
    error ZeroChainId();
    error ZeroDelegateSigner();
    error ZeroDelegateContract();

    // OperatorManager Error
    error InvalidBizType(uint8 bizType);
    error BatchIdNotMatch(uint64 batchId, uint64 futuresUploadBatchId);
    error CountNotMatch(uint256 length, uint256 count);
    error SignatureNotMatch();

    // VaultManager Error
    error EnumerableSetError();
    error RebalanceIdNotMatch(uint64 givenId, uint64 wantId); // the given rebalanceId not match the latest rebalanceId
    error RebalanceStillPending(); // the rebalance is still pending, so no need to upload again
    error RebalanceAlreadySucc(); // the rebalance is already succ, so no need to upload again
    error RebalanceMintUnexpected(); // the rebalance burn state or something is wrong, so the rebalance mint is unexpected. Should never happen.
    error RebalanceChainIdInvalid(uint256 chainId);
    error RebalanceTokenNotSupported(bytes32 tokenHash, uint256 chainId);

    // FeeManager Error
    error InvalidFeeCollectorType();

    // OperatorManagerZip Error
    error SymbolNotRegister();

    // Libraray Error
    // AccountTypeHelper
    error FrozenBalanceInconsistent(); // should never happen
    // SafeCastHelper
    error SafeCastOverflow();
    error SafeCastUnderflow();
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "./dataLayout/LedgerDataLayout.sol";
import "./interface/ILedger.sol";
import "./interface/IVaultManager.sol";
import "./interface/ILedgerCrossChainManager.sol";
import "./interface/IMarketManager.sol";
import "./interface/IFeeManager.sol";
import "./library/Utils.sol";
import "./library/Signature.sol";
import "./library/typesHelper/AccountTypeHelper.sol";
import "./library/typesHelper/AccountTypePositionHelper.sol";
import "./library/typesHelper/SafeCastHelper.sol";
import "./interface/ILedgerImplA.sol";

/// @title Ledger contract
/// @author Orderly_Rubick
/// @notice Ledger is responsible for saving traders' Account (balance, perpPosition, and other meta)
/// and global state (e.g. futuresUploadBatchId)
/// This contract should only have one in main-chain (e.g. OP orderly L2)
contract Ledger is ILedger, OwnableUpgradeable, LedgerDataLayout {
    using AccountTypeHelper for AccountTypes.Account;
    using AccountTypePositionHelper for AccountTypes.PerpPosition;
    using SafeCastHelper for *;

    // Using Storage as OZ 5.0 does
    struct LedgerStorage {
        // Because of EIP170 size limit, the implementation should be split to impl contracts
        address ledgerImplA;
    }

    // keccak256(abi.encode(uint256(keccak256("orderly.Ledger")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant LedgerStorageLocation = 0x220427b0bfdd3e8fe9a4c85265eee2c38bb3f4591655846e819d36b613b63200;

    function _getLedgerStorage() private pure returns (LedgerStorage storage $) {
        assembly {
            $.slot := LedgerStorageLocation
        }
    }

    // TODO ledgerImpl1, LedgerImpl2 addresses start here
    // usage: `ledgerImpl1.delegatecall(abi.encodeWithSelector(ILedger.accountDeposit.selector, data));`

    /// @notice require operator
    modifier onlyOperatorManager() {
        if (msg.sender != operatorManagerAddress) revert OnlyOperatorCanCall();
        _;
    }

    /// @notice require crossChainManager
    modifier onlyCrossChainManager() {
        if (msg.sender != crossChainManagerAddress) revert OnlyCrossChainManagerCanCall();
        _;
    }

    /// @notice check non-zero address
    modifier nonZeroAddress(address _address) {
        if (_address == address(0)) revert AddressZero();
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize() external override initializer {
        __Ownable_init();
    }

    /// @notice Set the address of ledgerImplA contract
    function setLedgerImplA(address _ledgerImplA) public override onlyOwner nonZeroAddress(_ledgerImplA) {
        emit ChangeLedgerImplA(_getLedgerStorage().ledgerImplA, _ledgerImplA);
        _getLedgerStorage().ledgerImplA = _ledgerImplA;
    }

    /// @notice Set the address of operatorManager contract
    /// @param _operatorManagerAddress new operatorManagerAddress
    function setOperatorManagerAddress(address _operatorManagerAddress)
        public
        override
        onlyOwner
        nonZeroAddress(_operatorManagerAddress)
    {
        emit ChangeOperatorManager(operatorManagerAddress, _operatorManagerAddress);
        operatorManagerAddress = _operatorManagerAddress;
    }

    /// @notice Set the address of crossChainManager on Ledger side
    /// @param _crossChainManagerAddress  new crossChainManagerAddress
    function setCrossChainManager(address _crossChainManagerAddress)
        public
        override
        onlyOwner
        nonZeroAddress(_crossChainManagerAddress)
    {
        emit ChangeCrossChainManager(crossChainManagerAddress, _crossChainManagerAddress);
        crossChainManagerAddress = _crossChainManagerAddress;
    }

    /// @notice Set the address of vaultManager contract
    /// @param _vaultManagerAddress new vaultManagerAddress
    function setVaultManager(address _vaultManagerAddress)
        public
        override
        onlyOwner
        nonZeroAddress(_vaultManagerAddress)
    {
        emit ChangeVaultManager(address(vaultManager), _vaultManagerAddress);
        vaultManager = IVaultManager(_vaultManagerAddress);
    }

    /// @notice Set the address of marketManager contract
    /// @param _marketManagerAddress new marketManagerAddress
    function setMarketManager(address _marketManagerAddress)
        public
        override
        onlyOwner
        nonZeroAddress(_marketManagerAddress)
    {
        emit ChangeMarketManager(address(marketManager), _marketManagerAddress);
        marketManager = IMarketManager(_marketManagerAddress);
    }

    /// @notice Set the address of feeManager contract
    /// @param _feeManagerAddress new feeManagerAddress
    function setFeeManager(address _feeManagerAddress) public override onlyOwner nonZeroAddress(_feeManagerAddress) {
        emit ChangeFeeManager(address(feeManager), _feeManagerAddress);
        feeManager = IFeeManager(_feeManagerAddress);
    }

    /// @notice Get the amount of a token frozen balance for a given account and the corresponding withdrawNonce
    /// @param accountId accountId to query
    /// @param withdrawNonce withdrawNonce to query
    /// @param tokenHash tokenHash to query
    /// @return uint128 frozen value
    function getFrozenWithdrawNonce(bytes32 accountId, uint64 withdrawNonce, bytes32 tokenHash)
        public
        view
        override
        returns (uint128)
    {
        return userLedger[accountId].getFrozenWithdrawNonceBalance(withdrawNonce, tokenHash);
    }

    /// @notice omni batch get
    /// @param accountIds accountId list to query
    /// @param tokens token list to query
    /// @param symbols symbol list to query
    /// @return accountSnapshots account snapshot list for the given tokens and symbols
    function batchGetUserLedger(bytes32[] calldata accountIds, bytes32[] memory tokens, bytes32[] memory symbols)
        public
        view
        override
        returns (AccountTypes.AccountSnapshot[] memory accountSnapshots)
    {
        uint256 accountIdLength = accountIds.length;
        uint256 tokenLength = tokens.length;
        uint256 symbolLength = symbols.length;
        accountSnapshots = new AccountTypes.AccountSnapshot[](accountIdLength);
        for (uint256 i = 0; i < accountIdLength; ++i) {
            bytes32 accountId = accountIds[i];
            AccountTypes.Account storage account = userLedger[accountId];
            AccountTypes.AccountTokenBalances[] memory tokenInner = new AccountTypes.AccountTokenBalances[](tokenLength);
            for (uint256 j = 0; j < tokenLength; ++j) {
                bytes32 tokenHash = tokens[j];
                tokenInner[j] = AccountTypes.AccountTokenBalances({
                    tokenHash: tokenHash,
                    balance: account.getBalance(tokenHash),
                    frozenBalance: account.getFrozenTotalBalance(tokenHash)
                });
            }
            AccountTypes.AccountPerpPositions[] memory symbolInner =
                new AccountTypes.AccountPerpPositions[](symbolLength);
            for (uint256 j = 0; j < symbolLength; ++j) {
                bytes32 symbolHash = symbols[j];
                AccountTypes.PerpPosition storage perpPosition = account.perpPositions[symbolHash];
                symbolInner[j] = AccountTypes.AccountPerpPositions({
                    symbolHash: symbolHash,
                    positionQty: perpPosition.positionQty,
                    costPosition: perpPosition.costPosition,
                    lastSumUnitaryFundings: perpPosition.lastSumUnitaryFundings,
                    lastExecutedPrice: perpPosition.lastExecutedPrice,
                    lastSettledPrice: perpPosition.lastSettledPrice,
                    averageEntryPrice: perpPosition.averageEntryPrice,
                    openingCost: perpPosition.openingCost,
                    lastAdlPrice: perpPosition.lastAdlPrice
                });
            }
            accountSnapshots[i] = AccountTypes.AccountSnapshot({
                accountId: accountId,
                brokerHash: account.brokerHash,
                userAddress: account.userAddress,
                lastWithdrawNonce: account.lastWithdrawNonce,
                lastPerpTradeId: account.lastPerpTradeId,
                lastEngineEventId: account.lastEngineEventId,
                lastDepositEventId: account.lastDepositEventId,
                tokenBalances: tokenInner,
                perpPositions: symbolInner
            });
        }
    }

    function batchGetUserLedger(bytes32[] calldata accountIds)
        public
        view
        returns (AccountTypes.AccountSnapshot[] memory)
    {
        bytes32[] memory tokens = vaultManager.getAllAllowedToken();
        bytes32[] memory symbols = vaultManager.getAllAllowedSymbol();
        return batchGetUserLedger(accountIds, tokens, symbols);
    }

    /// Interface implementation

    /// @notice The cross chain manager will call this function to notify the deposit event to the Ledger contract
    /// @param data account deposit data
    function accountDeposit(AccountTypes.AccountDeposit calldata data) external override onlyCrossChainManager {
        _delegatecall(abi.encodeWithSelector(ILedgerImplA.accountDeposit.selector, data));
    }

    function executeProcessValidatedFutures(PerpTypes.FuturesTradeUpload calldata trade)
        external
        override
        onlyOperatorManager
    {
        _delegatecall(abi.encodeWithSelector(ILedgerImplA.executeProcessValidatedFutures.selector, trade));
    }

    function executeWithdrawAction(EventTypes.WithdrawData calldata withdraw, uint64 eventId)
        external
        override
        onlyOperatorManager
    {
        _delegatecall(abi.encodeWithSelector(ILedgerImplA.executeWithdrawAction.selector, withdraw, eventId));
    }

    function accountWithDrawFinish(AccountTypes.AccountWithdraw calldata withdraw)
        external
        override
        onlyCrossChainManager
    {
        _delegatecall(abi.encodeWithSelector(ILedgerImplA.accountWithDrawFinish.selector, withdraw));
    }

    function executeSettlement(EventTypes.Settlement calldata settlement, uint64 eventId)
        external
        override
        onlyOperatorManager
    {
        _delegatecall(abi.encodeWithSelector(ILedgerImplA.executeSettlement.selector, settlement, eventId));
    }

    function executeLiquidation(EventTypes.Liquidation calldata liquidation, uint64 eventId)
        external
        override
        onlyOperatorManager
    {
        _delegatecall(abi.encodeWithSelector(ILedgerImplA.executeLiquidation.selector, liquidation, eventId));
    }

    function executeAdl(EventTypes.Adl calldata adl, uint64 eventId) external override onlyOperatorManager {
        _delegatecall(abi.encodeWithSelector(ILedgerImplA.executeAdl.selector, adl, eventId));
    }

    function executeFeeDistribution(EventTypes.FeeDistribution calldata feeDistribution, uint64 eventId)
        external
        override
        onlyOperatorManager
    {
        _delegatecall(abi.encodeWithSelector(ILedgerImplA.executeFeeDistribution.selector, feeDistribution, eventId));
    }

    function executeDelegateSigner(EventTypes.DelegateSigner calldata delegateSigner, uint64 eventId)
        external
        override
        onlyOperatorManager
    {
        _delegatecall(abi.encodeWithSelector(ILedgerImplA.executeDelegateSigner.selector, delegateSigner, eventId));
    }

    function executeDelegateWithdrawAction(EventTypes.WithdrawData calldata delegateWithdraw, uint64 eventId)
        external
        override
        onlyOperatorManager
    {
        _delegatecall(
            abi.encodeWithSelector(ILedgerImplA.executeDelegateWithdrawAction.selector, delegateWithdraw, eventId)
        );
    }

    function executeRebalanceBurn(RebalanceTypes.RebalanceBurnUploadData calldata data)
        external
        override
        onlyOperatorManager
    {
        (uint32 dstDomain, address dstVaultAddress) = vaultManager.executeRebalanceBurn(data);
        // send cc message with:
        // rebalanceId, amount, tokenHash, burnChainId, mintChainId | dstDomain, dstVaultAddress
        ILedgerCrossChainManager(crossChainManagerAddress).burn(
            RebalanceTypes.RebalanceBurnCCData({
                dstDomain: dstDomain,
                rebalanceId: data.rebalanceId,
                amount: data.amount,
                tokenHash: data.tokenHash,
                burnChainId: data.burnChainId,
                mintChainId: data.mintChainId,
                dstVaultAddress: dstVaultAddress
            })
        );
    }

    function rebalanceBurnFinish(RebalanceTypes.RebalanceBurnCCFinishData calldata data)
        external
        override
        onlyCrossChainManager
    {
        vaultManager.rebalanceBurnFinish(data);
    }

    function executeRebalanceMint(RebalanceTypes.RebalanceMintUploadData calldata data)
        external
        override
        onlyOperatorManager
    {
        vaultManager.executeRebalanceMint(data);
        // send cc Message with:
        // rebalanceId, amount, tokenHash, burnChainId, mintChainId | messageBytes, messageSignature
        ILedgerCrossChainManager(crossChainManagerAddress).mint(
            RebalanceTypes.RebalanceMintCCData({
                rebalanceId: data.rebalanceId,
                amount: data.amount,
                tokenHash: data.tokenHash,
                burnChainId: data.burnChainId,
                mintChainId: data.mintChainId,
                messageBytes: data.messageBytes,
                messageSignature: data.messageSignature
            })
        );
    }

    function rebalanceMintFinish(RebalanceTypes.RebalanceMintCCFinishData calldata data)
        external
        override
        onlyCrossChainManager
    {
        vaultManager.rebalanceMintFinish(data);
    }

    // inner function for delegatecall
    function _delegatecall(bytes memory data) private {
        (bool success, bytes memory returnData) = _getLedgerStorage().ledgerImplA.delegatecall(data);
        if (!success) {
            if (returnData.length > 0) {
                revert(string(returnData));
            } else {
                revert DelegatecallFail();
            }
        }
    }
}

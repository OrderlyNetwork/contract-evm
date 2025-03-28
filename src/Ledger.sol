// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.26;

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
import "./interface/ILedgerImplB.sol";
import "./interface/ILedgerImplC.sol";

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
        address ledgerImplB;
        address ledgerImplC;
    }

    // keccak256(abi.encode(uint256(keccak256("orderly.Ledger")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant LedgerStorageLocation = 0x220427b0bfdd3e8fe9a4c85265eee2c38bb3f4591655846e819d36b613b63200;

    function _getLedgerStorage() private pure returns (LedgerStorage storage $) {
        assembly {
            $.slot := LedgerStorageLocation
        }
    }

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

    /// @notice require crossChainManagerV2
    modifier onlyCrossChainManagerV2() {
        if (msg.sender != crossChainManagerV2Address) revert OnlyCrossChainManagerV2CanCall();
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
    function setLedgerImplA(address _ledgerImplA) external override onlyOwner nonZeroAddress(_ledgerImplA) {
        emit ChangeLedgerImplA(_getLedgerStorage().ledgerImplA, _ledgerImplA);
        _getLedgerStorage().ledgerImplA = _ledgerImplA;
    }

    /// @notice Set the address of ledgerImplB contract
    function setLedgerImplB(address _ledgerImplB) external override onlyOwner nonZeroAddress(_ledgerImplB) {
        emit ChangeLedgerImplB(_getLedgerStorage().ledgerImplB, _ledgerImplB);
        _getLedgerStorage().ledgerImplB = _ledgerImplB;
    }

    /// @notice Set the address of ledgerImplC contract
    function setLedgerImplC(address _ledgerImplC) external override onlyOwner nonZeroAddress(_ledgerImplC) {
        emit ChangeLedgerImplC(_getLedgerStorage().ledgerImplC, _ledgerImplC);
        _getLedgerStorage().ledgerImplC = _ledgerImplC;
    }

    /// @notice Set the address of operatorManager contract
    /// @param _operatorManagerAddress new operatorManagerAddress
    function setOperatorManagerAddress(address _operatorManagerAddress)
        external
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
        external
        override
        onlyOwner
        nonZeroAddress(_crossChainManagerAddress)
    {
        emit ChangeCrossChainManager(crossChainManagerAddress, _crossChainManagerAddress);
        crossChainManagerAddress = _crossChainManagerAddress;
    }

    /// @notice Set the address of crossChainManagerV2 on Ledger side
    /// @param _crossChainManagerV2Address  new crossChainManagerV2Address
    function setCrossChainManagerV2(address _crossChainManagerV2Address)
        external
        override
        onlyOwner
        nonZeroAddress(_crossChainManagerV2Address)
    {
        emit ChangeCrossChainManagerV2(crossChainManagerV2Address, _crossChainManagerV2Address);
        crossChainManagerV2Address = _crossChainManagerV2Address;
    }

    /// @notice Set the address of vaultManager contract
    /// @param _vaultManagerAddress new vaultManagerAddress
    function setVaultManager(address _vaultManagerAddress)
        external
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
        external
        override
        onlyOwner
        nonZeroAddress(_marketManagerAddress)
    {
        emit ChangeMarketManager(address(marketManager), _marketManagerAddress);
        marketManager = IMarketManager(_marketManagerAddress);
    }

    /// @notice Set the address of feeManager contract
    /// @param _feeManagerAddress new feeManagerAddress
    function setFeeManager(address _feeManagerAddress) external override onlyOwner nonZeroAddress(_feeManagerAddress) {
        emit ChangeFeeManager(address(feeManager), _feeManagerAddress);
        feeManager = IFeeManager(_feeManagerAddress);
    }

    /// @notice Get the amount of a token frozen balance for a given account and the corresponding withdrawNonce
    /// @param accountId accountId to query
    /// @param withdrawNonce withdrawNonce to query
    /// @param tokenHash tokenHash to query
    /// @return uint128 frozen value
    function getFrozenWithdrawNonce(bytes32 accountId, uint64 withdrawNonce, bytes32 tokenHash)
        external
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
                perpPositions: symbolInner,
                lastDepositSrcChainId: account.lastDepositSrcChainId,
                lastDepositSrcChainNonce: account.lastDepositSrcChainNonce
            });
        }
    }

    function batchGetUserLedger(bytes32[] calldata accountIds)
        external
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
        _delegatecall(
            abi.encodeWithSelector(ILedgerImplA.accountDeposit.selector, data), _getLedgerStorage().ledgerImplA
        );
    }

    function accountDepositSol(AccountTypes.AccountDepositSol calldata data)
        external
        override
        onlyCrossChainManagerV2
    {
        _delegatecall(
            abi.encodeWithSelector(ILedgerImplC.accountDepositSol.selector, data), _getLedgerStorage().ledgerImplC
        );
    }

    function executeProcessValidatedFutures(PerpTypes.FuturesTradeUpload calldata trade)
        external
        override
        onlyOperatorManager
    {
        _delegatecall(
            abi.encodeWithSelector(ILedgerImplA.executeProcessValidatedFutures.selector, trade),
            _getLedgerStorage().ledgerImplA
        );
    }

    function executeProcessValidatedFuturesBatch(PerpTypes.FuturesTradeUpload[] calldata trades)
        external
        override
        onlyOperatorManager
    {
        _delegatecall(
            abi.encodeWithSelector(ILedgerImplB.executeProcessValidatedFuturesBatch.selector, trades),
            _getLedgerStorage().ledgerImplB
        );
    }

    function executeWithdrawAction(EventTypes.WithdrawData calldata withdraw, uint64 eventId)
        external
        override
        onlyOperatorManager
    {
        _delegatecall(
            abi.encodeWithSelector(ILedgerImplA.executeWithdrawAction.selector, withdraw, eventId),
            _getLedgerStorage().ledgerImplA
        );
    }

    function executeWithdrawSolAction(EventTypes.WithdrawDataSol calldata withdraw, uint64 eventId)
        external
        override
        onlyOperatorManager
    {
        _delegatecall(
            abi.encodeWithSelector(ILedgerImplC.executeWithdrawSolAction.selector, withdraw, eventId),
            _getLedgerStorage().ledgerImplC
        );
    }

    function accountWithdrawFail(AccountTypes.AccountWithdraw memory withdraw) external override onlyOwner {
        _delegatecall(
            abi.encodeWithSelector(ILedgerImplA.accountWithdrawFail.selector, withdraw), _getLedgerStorage().ledgerImplA
        );
    }

    function accountWithDrawFinish(AccountTypes.AccountWithdraw calldata withdraw)
        external
        override
        onlyCrossChainManager
    {
        _delegatecall(
            abi.encodeWithSelector(ILedgerImplA.accountWithDrawFinish.selector, withdraw),
            _getLedgerStorage().ledgerImplA
        );
    }

    function executeSettlement(EventTypes.Settlement calldata settlement, uint64 eventId)
        external
        override
        onlyOperatorManager
    {
        _delegatecall(
            abi.encodeWithSelector(ILedgerImplA.executeSettlement.selector, settlement, eventId),
            _getLedgerStorage().ledgerImplA
        );
    }

    function executeLiquidation(EventTypes.Liquidation calldata liquidation, uint64 eventId)
        external
        override
        onlyOperatorManager
    {
        _delegatecall(
            abi.encodeWithSelector(ILedgerImplA.executeLiquidation.selector, liquidation, eventId),
            _getLedgerStorage().ledgerImplA
        );
    }

    function executeLiquidationV2(EventTypes.LiquidationV2 calldata liquidation, uint64 eventId)
        external
        override
        onlyOperatorManager
    {
        _delegatecall(
            abi.encodeWithSelector(ILedgerImplA.executeLiquidationV2.selector, liquidation, eventId),
            _getLedgerStorage().ledgerImplA
        );
    }

    function executeAdl(EventTypes.Adl calldata adl, uint64 eventId) external override onlyOperatorManager {
        _delegatecall(
            abi.encodeWithSelector(ILedgerImplA.executeAdl.selector, adl, eventId), _getLedgerStorage().ledgerImplA
        );
    }

    function executeAdlV2(EventTypes.AdlV2 calldata adl, uint64 eventId) external override onlyOperatorManager {
        _delegatecall(
            abi.encodeWithSelector(ILedgerImplA.executeAdlV2.selector, adl, eventId), _getLedgerStorage().ledgerImplA
        );
    }

    function executeFeeDistribution(EventTypes.FeeDistribution calldata feeDistribution, uint64 eventId)
        external
        override
        onlyOperatorManager
    {
        _delegatecall(
            abi.encodeWithSelector(ILedgerImplA.executeFeeDistribution.selector, feeDistribution, eventId),
            _getLedgerStorage().ledgerImplA
        );
    }

    function executeDelegateSigner(EventTypes.DelegateSigner calldata delegateSigner, uint64 eventId)
        external
        override
        onlyOperatorManager
    {
        _delegatecall(
            abi.encodeWithSelector(ILedgerImplA.executeDelegateSigner.selector, delegateSigner, eventId),
            _getLedgerStorage().ledgerImplA
        );
    }

    function executeDelegateWithdrawAction(EventTypes.WithdrawData calldata delegateWithdraw, uint64 eventId)
        external
        override
        onlyOperatorManager
    {
        _delegatecall(
            abi.encodeWithSelector(ILedgerImplA.executeDelegateWithdrawAction.selector, delegateWithdraw, eventId),
            _getLedgerStorage().ledgerImplA
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

    function executeWithdraw2Contract(EventTypes.Withdraw2Contract calldata data, uint64 eventId)
        external
        override
        onlyOperatorManager
    {
        _delegatecall(
            abi.encodeWithSelector(ILedgerImplC.executeWithdraw2Contract.selector, data, eventId),
            _getLedgerStorage().ledgerImplC
        );
    }

    // inner function for delegatecall
    function _delegatecall(bytes memory data, address impl) private {
        (bool success, bytes memory returnData) = impl.delegatecall(data);
        if (!success) {
            if (returnData.length > 0) {
                assembly {
                    revert(add(32, returnData), mload(returnData))
                }
            } else {
                revert DelegatecallFail();
            }
        }
    }
}

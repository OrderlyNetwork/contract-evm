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
import "./interface/ILedgerCrossChainManagerV2.sol";
import "./interface/ILedgerImplA.sol";
import "./interface/ILedgerImplB.sol";
import "./interface/ILedgerImplC.sol";
import "./interface/ILedgerImplD.sol";

import "./oz5Revised/AccessControlRevised.sol";

/// @title Ledger contract
/// @author Orderly_Rubick
/// @notice Ledger is responsible for saving traders' Account (balance, perpPosition, and other meta)
/// and global state (e.g. futuresUploadBatchId)
/// This contract should only have one in main-chain (e.g. OP orderly L2)
contract Ledger is ILedger, OwnableUpgradeable, LedgerDataLayout, AccessControlRevised {
    using AccountTypeHelper for AccountTypes.Account;
    using AccountTypePositionHelper for AccountTypes.PerpPosition;
    using SafeCastHelper for *;

    // Using Storage as OZ 5.0 does
    struct LedgerStorage {
        // Because of EIP170 size limit, the implementation should be split to impl contracts
        address ledgerImplA;
        address ledgerImplB;
        address ledgerImplC;
        address ledgerImplD;
    }

    // keccak256(abi.encode(uint256(keccak256("orderly.Ledger")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant LedgerStorageLocation = 0x220427b0bfdd3e8fe9a4c85265eee2c38bb3f4591655846e819d36b613b63200;

    /* ================ Role ================ */
    // bytes32 public constant SYMBOL_MANAGER_ROLE = keccak256("ORDERLY_MANAGER_SYMBOL_MANAGER_ROLE");
    bytes32 public constant BROKER_MANAGER_ROLE = keccak256("ORDERLY_MANAGER_BROKER_MANAGER_ROLE");

    function _getLedgerStorage() private pure returns (LedgerStorage storage $) {
        assembly {
            $.slot := LedgerStorageLocation
        }
    }

    /// @notice check if the caller is the owner or has the role
    modifier onlyOwnerOrRole(bytes32 role) {
        if (!hasRole(role, msg.sender) && msg.sender != owner()) {
            revert AccessControlUnauthorizedAccount(msg.sender, role);
        }
        _;
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

    /// @notice Set the address of ledgerImplD contract
    function setLedgerImplD(address _ledgerImplD) external override onlyOwner nonZeroAddress(_ledgerImplD) {
        emit ChangeLedgerImplD(_getLedgerStorage().ledgerImplD, _ledgerImplD);
        _getLedgerStorage().ledgerImplD = _ledgerImplD;
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

    /// @notice Set the address of prime wallet for a given accountId
    /// @param id accountId or spId
    /// @param _primeWallet address of the prime wallet
    function setPrimeWallet(bytes32 id, address _primeWallet) external onlyOwner nonZeroAddress(_primeWallet) {
        idToPrimeWallet[id] = _primeWallet;
        emit PrimeWalletSet(id, _primeWallet);
    }

    /// @notice Set the address of prime wallet on Solana for a given accountId
    /// @param _id accountId or spId
    /// @param _solanaPrimeWallet address of the prime wallet
    function setSolanaPrimeWallet(bytes32 _id, bytes32 _solanaPrimeWallet) external onlyOwner {
        require(_solanaPrimeWallet != bytes32(0), "Zero Solana Prime Wallet");
        idToSolanaPrimeWallet[_id] = _solanaPrimeWallet;
        emit SolanaPrimeWalletSet(_id, _solanaPrimeWallet);
    }

     function setValidVault(address vault, bool isValid) external onlyOwner {
        isValidVault[vault] = isValid;
        emit VaultSet(vault, isValid);
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

    function getUserTokenBalance(bytes32 accountId, bytes32 tokenHash) external view override returns (int128) {
        return userLedger[accountId].getBalance(tokenHash);
    }

    function getUserEscrowBalance(bytes32 accountId, bytes32 tokenHash) external view override returns (uint128) {
        return escrowBalances[accountId][tokenHash];
    }

    function getUserTotalFrozenBalance(bytes32 accountId, bytes32 tokenHash) external view override returns (uint128) {
        return userLedger[accountId].getFrozenTotalBalance(tokenHash);
    }

    function getBalanceTransferState(uint256 transferId)
        external
        view
        override
        returns (EventTypes.InternalTransferTrack memory)
    {
        return transfers[transferId];
    }

    function getLedgerImpl() external view returns (address, address, address, address) {
        LedgerStorage storage $ = _getLedgerStorage();
        return ($.ledgerImplA, $.ledgerImplB, $.ledgerImplC, $.ledgerImplD);
    }

    /// Interface implementation

    /// @notice The cross chain manager will call this function to notify the deposit event to the Ledger contract
    /// @param data account deposit data
    function accountDeposit(AccountTypes.AccountDeposit calldata data) external override onlyCrossChainManager {
        _delegatecall(
            abi.encodeWithSelector(ILedgerImplA.accountDeposit.selector, data), _getLedgerStorage().ledgerImplA
        );
    }

    function accountDepositSol(AccountTypes.AccountDepositSol calldata data) external override onlyCrossChainManagerV2 {
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
        ILedgerCrossChainManager(crossChainManagerAddress)
            .burn(
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
        ILedgerCrossChainManager(crossChainManagerAddress)
            .mint(
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
            abi.encodeWithSelector(ILedgerImplD.executeWithdraw2Contract.selector, data, eventId),
            _getLedgerStorage().ledgerImplD
        );
    }

    function executeBalanceTransfer(EventTypes.BalanceTransfer calldata balanceTransfer, uint64 eventId)
        external
        override
        onlyOperatorManager
    {
        _delegatecall(
            abi.encodeWithSelector(ILedgerImplC.executeBalanceTransfer.selector, balanceTransfer, eventId),
            _getLedgerStorage().ledgerImplC
        );
    }

    function executeSwapResultUpload(EventTypes.SwapResult calldata swapResultUpload, uint64 eventId)
        external
        override
        onlyOperatorManager
    {
        _delegatecall(
            abi.encodeWithSelector(ILedgerImplD.executeSwapResultUpload.selector, swapResultUpload, eventId),
            _getLedgerStorage().ledgerImplD
        );
    }

    function executeWithdraw2ContractV2(EventTypes.Withdraw2ContractV2 calldata withdraw2ContractV2, uint64 eventId)
        external
        override
        onlyOperatorManager
    {
        _delegatecall(
            abi.encodeWithSelector(ILedgerImplD.executeWithdraw2ContractV2.selector, withdraw2ContractV2, eventId),
            _getLedgerStorage().ledgerImplD
        );
    }

    /// @notice Initiates cross-chain broker status modification to multiple vault chains
    /// @dev Only callable by owner, triggers cross-contract calls to VaultManager and LedgerCrossChainManager
    /// @param chainIds Array of destination chain IDs where broker status should be modified
    /// @param brokerHash Hash of the broker to be modified
    /// @param allowed true to add broker, false to remove broker 
    /// @param setBrokerIndex true to set broker index, false otherwise
    /// @param brokerIndex Index number to assign to the broker if setBrokerIndex is true
    function setBrokerFromLedger(
        uint256[] calldata chainIds, 
        bytes32 brokerHash, 
        bool allowed,
        bool setBrokerIndex,
        uint16 brokerIndex
    ) external override onlyOwnerOrRole(BROKER_MANAGER_ROLE) {
        // Validate input parameters
        require(chainIds.length > 0, "Ledger: empty chainIds");
        
        // Step 1: Update local VaultManager state for the broker
        // This updates the broker status in the local Ledger chain
        vaultManager.setBrokerFromLedger(brokerHash, allowed);
        
        // Step 2: Trigger cross-chain messages
        // Call LedgerCrossChainManager to send messages to vault chains
        ILedgerCrossChainManager(crossChainManagerAddress).setBrokerCrossChain(
            chainIds, 
            brokerHash, 
            allowed
        );

        // Step 3: Set broker hash and its index number if this broker should be supported on Solana chain
        if (allowed && setBrokerIndex) {
            ILedgerCrossChainManagerV2(crossChainManagerV2Address).setBrokerFromLedger(msg.sender, brokerHash, brokerIndex);
        }

        
        emit SetBrokerFromLedgerInitiated(chainIds, brokerHash, allowed);
    }

    /* ================ Override AccessControlRevised To Simplify Access Control ================ */

    /// @notice Override grantRole
    function grantRole(bytes32 role, address account) public override onlyOwner {
        _grantRole(role, account);
    }

    /// @notice Override revokeRole
    function revokeRole(bytes32 role, address account) public override onlyOwner {
        _revokeRole(role, account);
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

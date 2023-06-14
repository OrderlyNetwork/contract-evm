// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./interface/ILedger.sol";
import "./interface/IVaultManager.sol";
import "./interface/ILedgerCrossChainManager.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./library/FeeCollector.sol";
import "./library/Utils.sol";
import "./library/TypesHelper/AccountTypeHelper.sol";
import "./library/VerifyEIP712.sol";

/**
 * Ledger is responsible for saving traders' Account (balance, perpPosition, and other meta)
 * and global state (e.g. futuresUploadBatchId)
 * This contract should only have one in main-chain (avalanche)
 */
contract Ledger is ILedger, Ownable {
    using AccountTypeHelper for AccountTypes.Account;
    using AccountTypeHelper for AccountTypes.PerpPosition;

    // OperatorManager contract address
    address public operatorManagerAddress;
    // crossChainManagerAddress contract address
    address public crossChainManagerAddress;
    // operatorTradesBatchId
    uint256 public operatorTradesBatchId;
    // globalEventId, for deposit and withdraw
    uint256 public globalEventId;
    // globalDepositId
    uint64 public globalDepositId;
    // userLedger accountId -> Account
    mapping(bytes32 => AccountTypes.Account) private userLedger;
    // insuranceFundAccountId
    bytes32 private insuranceFundAccountId;
    // VaultManager contract
    IVaultManager public vaultManager;
    // CrossChainManager contract
    ILedgerCrossChainManager public crossChainManager;

    // require operator
    modifier onlyOperatorManager() {
        require(msg.sender == operatorManagerAddress, "only operator can call");
        _;
    }

    // require crossChainManager
    modifier onlyCrossChainManager() {
        require(msg.sender == crossChainManagerAddress, "only crossChainManager can call");
        _;
    }

    // set operatorManagerAddress
    function setOperatorManagerAddress(address _operatorManagerAddress) public override onlyOwner {
        operatorManagerAddress = _operatorManagerAddress;
    }

    // set crossChainManager & Address
    function setCrossChainManager(address _crossChainManagerAddress) public override onlyOwner {
        crossChainManagerAddress = _crossChainManagerAddress;
        crossChainManager = ILedgerCrossChainManager(_crossChainManagerAddress);
    }

    // set insuranceFundAccountId
    function setInsuranceFundAccountId(bytes32 _insuranceFundAccountId) public override onlyOwner {
        insuranceFundAccountId = _insuranceFundAccountId;
    }

    // set vaultManager
    function setVaultManager(address _vaultManagerAddress) public override onlyOwner {
        vaultManager = IVaultManager(_vaultManagerAddress);
    }

    // get userLedger balance
    function getUserLedgerBalance(bytes32 accountId, bytes32 tokenHash) public view override returns (uint256) {
        return userLedger[accountId].getBalance(tokenHash);
    }

    // get userLedger brokerId
    function getUserLedgerBrokerHash(bytes32 accountId) public view override returns (bytes32) {
        return userLedger[accountId].getBrokerHash();
    }

    // get userLedger lastCefiEventId
    function getUserLedgerLastCefiEventId(bytes32 accountId) public view override returns (uint256) {
        return userLedger[accountId].getLastCefiEventId();
    }

    // get frozen total balance
    function getFrozenTotalBalance(bytes32 accountId, bytes32 tokenHash) public view override returns (uint256) {
        return userLedger[accountId].getFrozenTotalBalance(tokenHash);
    }

    // get frozen withdrawNonce balance
    function getFrozenWithdrawNonce(bytes32 accountId, uint64 withdrawNonce, bytes32 tokenHash)
        public
        view
        override
        returns (uint256)
    {
        return userLedger[accountId].getFrozenWithdrawNonceBalance(withdrawNonce, tokenHash);
    }

    // Interface implementation

    function accountDeposit(AccountTypes.AccountDeposit calldata data) public override onlyCrossChainManager {
        // a not registerd account can still deposit, because of the consistency
        AccountTypes.Account storage account = userLedger[data.accountId];
        if (account.userAddress == address(0)) {
            // register account first
            account.userAddress = data.userAddress;
            account.brokerHash = data.brokerHash;
            // emit register event
            emit AccountRegister(data.accountId, data.brokerHash, data.userAddress, block.timestamp);
        }
        account.addBalance(data.tokenHash, data.tokenAmount);
        vaultManager.addBalance(data.srcChainId, data.tokenHash, data.tokenAmount);
        // emit deposit event
        emit AccountDeposit(
            data.accountId,
            _newGlobalDepositId(),
            _newGlobalEventId(),
            data.userAddress,
            data.tokenHash,
            data.tokenAmount,
            data.srcChainId,
            data.srcChainDepositNonce,
            data.brokerHash,
            block.timestamp
        );
    }

    function updateUserLedgerByTradeUpload(PerpTypes.FuturesTradeUpload calldata trade)
        public
        override
        onlyOperatorManager
    {
        AccountTypes.Account storage account = userLedger[trade.accountId];
        account.lastPerpTradeId = trade.tradeId;
        // TODO update account.prep_position
    }

    function executeWithdrawAction(EventTypes.WithdrawData calldata withdraw, uint256 eventId)
        public
        override
        onlyOperatorManager
    {
        bytes32 tokenHash = Utils.string2HashedBytes32(withdraw.tokenSymbol);
        AccountTypes.Account storage account = userLedger[withdraw.accountId];
        uint8 state = 0;
        if (account.balances[tokenHash] < withdraw.tokenAmount) {
            // require balance enough
            state = 1;
        } else if (vaultManager.getBalance(withdraw.chainId, tokenHash) < withdraw.tokenAmount) {
            // require chain has enough balance
            state = 2;
        } else if (account.lastWithdrawNonce >= withdraw.withdrawNonce) {
            // require withdraw nonce inc
            state = 3;
        } else if (!VerifyEIP712.verifyWithdraw(withdraw.sender, withdraw)) {
            // require signature verify
            state = 4;
        }
        // check all assert, should not change any status
        if (state != 0) {
            emit AccountWithdrawFail(
                withdraw.accountId,
                withdraw.withdrawNonce,
                _newGlobalEventId(),
                account.brokerHash,
                withdraw.sender,
                withdraw.receiver,
                withdraw.chainId,
                tokenHash,
                withdraw.tokenAmount,
                withdraw.fee,
                block.timestamp,
                state
            );
            return;
        }
        // update status, should never fail
        // frozen balance
        account.frozenBalance(withdraw.withdrawNonce, tokenHash, withdraw.tokenAmount);
        account.lastWithdrawNonce = withdraw.withdrawNonce;
        vaultManager.subBalance(withdraw.chainId, tokenHash, withdraw.tokenAmount);
        account.lastCefiEventId = eventId;
        // emit withdraw approve event
        emit AccountWithdrawApprove(
            withdraw.accountId,
            withdraw.withdrawNonce,
            _newGlobalEventId(),
            account.brokerHash,
            withdraw.sender,
            withdraw.receiver,
            withdraw.chainId,
            tokenHash,
            withdraw.tokenAmount,
            withdraw.fee,
            block.timestamp
        );
        // send cross-chain tx
        crossChainManager.withdraw(withdraw);
    }

    function accountWithDrawFinish(AccountTypes.AccountWithdraw calldata withdraw)
        public
        override
        onlyCrossChainManager
    {
        AccountTypes.Account storage account = userLedger[withdraw.accountId];
        // finish frozen balance
        account.finishFrozenBalance(withdraw.withdrawNonce, withdraw.tokenHash, withdraw.tokenAmount);
        // emit withdraw finish event
        emit AccountWithdrawFinish(
            withdraw.accountId,
            withdraw.withdrawNonce,
            _newGlobalEventId(),
            account.brokerHash,
            withdraw.sender,
            withdraw.receiver,
            withdraw.chainId,
            withdraw.tokenHash,
            withdraw.tokenAmount,
            withdraw.fee,
            block.timestamp
        );
    }

    function executeSettlement(EventTypes.LedgerData calldata ledger, uint256 eventId)
        public
        override
        onlyOperatorManager
    {
        // check total settle amount zero
        int256 totalSettleAmount = 0;
        // gas saving
        uint256 length = ledger.ledgerExecutions.length;
        EventTypes.LedgerExecution[] calldata ledgerExecutions = ledger.ledgerExecutions;
        for (uint256 i = 0; i < length; ++i) {
            totalSettleAmount += ledgerExecutions[i].settledAmount;
        }
        require(totalSettleAmount == 0, "total settle amount not zero");

        AccountTypes.Account storage account = userLedger[ledger.accountId];
        uint256 balance = account.balances[ledger.settledAsset];
        account.hasPendingLedgerRequest = false;
        if (ledger.insuranceTransferAmount != 0) {
            // transfer insurance fund
            if (int256(balance) + int256(ledger.insuranceTransferAmount) + ledger.settledAmount < 0) {
                // overflow
                revert("Insurance transfer amount invalid");
            }
            AccountTypes.Account storage insuranceFund = userLedger[insuranceFundAccountId];
            insuranceFund.balances[ledger.settledAsset] += ledger.insuranceTransferAmount;
        }
        // for-loop ledger execution
        for (uint256 i = 0; i < length; ++i) {
            EventTypes.LedgerExecution calldata ledgerExecution = ledgerExecutions[i];
            AccountTypes.PerpPosition storage position = account.perpPositions[ledgerExecution.symbol];
            if (position.positionQty != 0) {
                position.chargeFundingFee(ledgerExecution.sumUnitaryFundings);
                position.cost_position += ledgerExecution.settledAmount;
                position.lastExecutedPrice = ledgerExecution.markPrice;
            }
            // check balance + settledAmount >= 0, where balance should cast to int256 first
            require(int256(balance) + ledgerExecution.settledAmount >= 0, "balance not enough");
            balance = uint256(int256(balance) + ledgerExecution.settledAmount);
        }
        account.lastCefiEventId = eventId;
        // TODO emit event
    }

    function executeLiquidation(EventTypes.LiquidationData calldata liquidation, uint256 eventId)
        public
        override
        onlyOperatorManager
    {
        AccountTypes.Account storage liquidated_user = userLedger[liquidation.accountId];
        // for-loop liquidation execution
        uint256 length = liquidation.liquidationTransfers.length;
        EventTypes.LiquidationTransfer[] calldata liquidationTransfers = liquidation.liquidationTransfers;
        // chargeFundingFee for liquidated_user.perpPosition
        for (uint256 i = 0; i < length; ++i) {
            liquidated_user.perpPositions[liquidation.liquidatedAsset].chargeFundingFee(
                liquidationTransfers[i].sumUnitaryFundings
            );
        }
        // TODO get_liquidation_info
        // TODO transfer_liquidatedAsset_to_insurance if insuranceTransferAmount != 0
        for (uint256 i = 0; i < length; ++i) {
            // TODO liquidator_liquidate_and_update_eventId
            // TODO liquidated_user_liquidate
            // TODO insurance_liquidate
        }
        liquidated_user.lastCefiEventId = eventId;
        // TODO emit event
    }

    function _newGlobalEventId() internal returns (uint256) {
        globalEventId += 1;
        return globalEventId;
    }

    function _newGlobalDepositId() internal returns (uint64) {
        globalDepositId += 1;
        return globalDepositId;
    }
}

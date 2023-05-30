// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./interface/ISettlement.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./library/FeeCollector.sol";
import "./library/Utils.sol";

/**
 * Settlement is responsible for saving traders' Account (balance, perpPosition, and other meta)
 * and global state (e.g. futuresUploadBatchId)
 * This contract should only have one in main-chain (avalanche)
 */
contract Settlement is FeeCollector, ISettlement {
    // OperatorManager contract address
    address public operatorManagerAddress;
    // crossChainManagerAddress contract address
    address public crossChainManagerAddress;
    // globalWithdrawId
    uint256 public globalWithdrawId;
    // operatorTradesBatchId
    uint256 public operatorTradesBatchId;
    // globalEventId
    uint256 public globalEventId;
    // userLedger accountId -> Account
    mapping(bytes32 => AccountTypes.Account) private userLedger;
    // insuranceFundAccountId
    bytes32 private insuranceFundAccountId;
    // valut balance, used for check if withdraw is valid
    mapping(uint256 => mapping(bytes32 => uint256)) chain2symbol2balance;

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
    function setOperatorManagerAddress(address _operatorManagerAddress) public onlyOwner {
        operatorManagerAddress = _operatorManagerAddress;
    }

    // set crossChainManagerAddress
    function setCrossChainManagerAddress(address _crossChainManagerAddress) public onlyOwner {
        crossChainManagerAddress = _crossChainManagerAddress;
    }

    // set insuranceFundAccountId
    function setInsuranceFundAccountId(bytes32 _insuranceFundAccountId) public onlyOwner {
        insuranceFundAccountId = _insuranceFundAccountId;
    }

    // constructor
    // call `setInsuranceFundAccountId` later
    constructor(address _operatorManagerAddress, address _crossChainManagerAddress) {
        operatorManagerAddress = _operatorManagerAddress;
        crossChainManagerAddress = _crossChainManagerAddress;
    }

    // get userLedger balance
    function getUserLedgerBalance(bytes32 accountId, bytes32 symbol) public view returns (uint256) {
        return userLedger[accountId].balances[symbol];
    }

    // get userLedger brokerId
    function getUserLedgerBrokerId(bytes32 accountId) public view returns (bytes32) {
        return userLedger[accountId].brokerId;
    }

    // Interface implementation

    function accountRegister(AccountTypes.AccountRegister calldata data) public override onlyOperatorManager {
        // check account not exist
        require(userLedger[data.accountId].primaryAddress == address(0), "account already registered");
        // check accountId is correct by Utils.getAccountId
        require(data.accountId == Utils.getAccountId(data.addr, data.brokerId), "accountId not match");
        AccountTypes.Account storage account = userLedger[data.accountId];
        account.primaryAddress = data.addr;
        EnumerableSet.add(account.addresses, data.addr);
        account.brokerId = data.brokerId;
        // emit register event
        emit AccountRegister(data.accountId, data.brokerId, data.addr);
    }

    function accountDeposit(AccountTypes.AccountDeposit calldata data) public override onlyCrossChainManager {
        // a not registerd account can still deposit, because of the consistency
        AccountTypes.Account storage account = userLedger[data.accountId];
        account.balances[data.symbol] += data.amount;
        chain2symbol2balance[data.chainId][data.symbol] += data.amount;
        // emit deposit event
        emit AccountDeposit(data.accountId, data.addr, data.symbol, data.chainId, data.amount);
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

    function executeWithdrawAction(PerpTypes.WithdrawData calldata withdraw, uint256 eventId)
        public
        override
        onlyOperatorManager
    {
        AccountTypes.Account storage account = userLedger[withdraw.accountId];
        // require balance enough
        require(account.balances[withdraw.symbol] >= withdraw.amount, "user balance not enough");
        // require addr is in account.addresses
        require(EnumerableSet.contains(account.addresses, withdraw.addr), "addr not in account");
        // require chain has enough balance
        require(
            chain2symbol2balance[withdraw.chainId][withdraw.symbol] >= withdraw.amount,
            "target chain balance not enough"
        );
        // update balance
        account.balances[withdraw.symbol] -= withdraw.amount;
        chain2symbol2balance[withdraw.chainId][withdraw.symbol] -= withdraw.amount;
        // TODO @Lewis send cross-chain tx
        account.lastCefiEventId = eventId;
        // emit withdraw event
        emit AccountWithdraw(withdraw.accountId, withdraw.addr, withdraw.symbol, withdraw.chainId, withdraw.amount);
    }

    function executeSettlement(PerpTypes.Settlement calldata settlement, uint256 eventId)
        public
        override
        onlyOperatorManager
    {
        // check total settle amount zero
        int256 totalSettleAmount = 0;
        // gas saving
        uint256 length = settlement.settlementExecutions.length;
        PerpTypes.SettlementExecution[] calldata settlementExecutions = settlement.settlementExecutions;
        for (uint256 i = 0; i < length; ++i) {
            totalSettleAmount += settlementExecutions[i].settledAmount;
        }
        require(totalSettleAmount == 0, "total settle amount not zero");

        AccountTypes.Account storage account = userLedger[settlement.accountId];
        uint256 balance = account.balances[settlement.settledAsset];
        account.hasPendingSettlementRequest = false;
        if (settlement.insuranceTransferAmount != 0) {
            // transfer insurance fund
            if (int256(balance) + int256(settlement.insuranceTransferAmount) + settlement.settledAmount < 0) {
                // overflow
                revert("Insurance transfer amount invalid");
            }
            AccountTypes.Account storage insuranceFund = userLedger[insuranceFundAccountId];
            insuranceFund.balances[settlement.settledAsset] += settlement.insuranceTransferAmount;
        }
        // for-loop settlement execution
        for (uint256 i = 0; i < length; ++i) {
            PerpTypes.SettlementExecution calldata settlementExecution = settlementExecutions[i];
            AccountTypes.PerpPosition storage position = account.perpPositions[settlementExecution.symbol];
            if (position.positionQty != 0) {
                AccountTypes.chargeFundingFee(position, settlementExecution.sumUnitaryFundings);
                position.cost_position += settlementExecution.settledAmount;
                position.lastExecutedPrice = settlementExecution.markPrice;
            }
            // check balance + settledAmount >= 0, where balance should cast to int256 first
            require(int256(balance) + settlementExecution.settledAmount >= 0, "balance not enough");
            balance = uint256(int256(balance) + settlementExecution.settledAmount);
        }
        account.lastCefiEventId = eventId;
    }

    function executeLiquidation(PerpTypes.Liquidation calldata liquidation, uint256 eventId)
        public
        override
        onlyOperatorManager
    {
        AccountTypes.Account storage liquidated_user = userLedger[liquidation.accountId];
        // for-loop liquidation execution
        uint256 length = liquidation.liquidationTransfers.length;
        PerpTypes.LiquidationTransfer[] calldata liquidationTransfers = liquidation.liquidationTransfers;
        // chargeFundingFee for liquidated_user.perpPosition
        for (uint256 i = 0; i < length; ++i) {
            AccountTypes.chargeFundingFee(
                liquidated_user.perpPositions[liquidation.liquidatedAsset], liquidationTransfers[i].sumUnitaryFundings
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

    function _new_globalEventId() internal returns (uint256) {
        globalEventId += 1;
        return globalEventId;
    }

    function _new_withdrawId() internal returns (uint256) {
        globalWithdrawId += 1;
        return globalWithdrawId;
    }
}

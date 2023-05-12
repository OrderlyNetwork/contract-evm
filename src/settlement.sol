// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./interface/ISettlement.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * Settlement is responsible for saving traders' Account (balance, perpPosition, and other meta)
 * and global state (e.g. futuresUploadBatchId)
 * This contract should only have one in main-chain (avalanche)
 */
contract Settlement is Ownable, ISettlement {
    // OperatorManager contract address
    address public operatorManagerAddress;
    // globalWithdrawId
    uint256 public globalWithdrawId;
    // operatorTradesBatchId
    uint256 public operatorTradesBatchId;
    // globalEventId
    uint256 public globalEventId;
    // userLedger
    mapping(bytes32 => AccountTypes.Account) private userLedger;
    // insuranceFundAccountId
    bytes32 private insuranceFundAccountId;

    // require operator
    modifier onlyOperatorManager() {
        require(msg.sender == operatorManagerAddress, "only operator can call");
        _;
    }

    // set operatorManagerAddress
    function setOperatorManagerAddress(address _operatorManagerAddress) public onlyOwner {
        operatorManagerAddress = _operatorManagerAddress;
    }

    // set insuranceFundAccountId
    function setInsuranceFundAccountId(bytes32 _insuranceFundAccountId) public onlyOwner {
        insuranceFundAccountId = _insuranceFundAccountId;
    }

    // Interface implementation

    function accountRegister(AccountTypes.AccountRegister calldata data) public override onlyOperatorManager {
        // check account not exist
        require(userLedger[data.accountId].accountId != bytes32(0), "account already exist");
        AccountTypes.Account storage account = userLedger[data.accountId];
        account.accountId = data.accountId;
        EnumerableSet.add(account.addresses, data.addr);
        account.brokerId = data.brokerId;
        // TODO emit event
    }

    function accountDeposit(AccountTypes.AccountDeposit calldata data) public override onlyOperatorManager {
        // a not registerd account can still deposit, because of the consistency
        AccountTypes.Account storage account = userLedger[data.accountId];
        account.balance += data.amount;
        // TODO emit deposit event
    }

    function updateUserLedgerByTradeUpload(PrepTypes.FuturesTradeUpload calldata trade)
        public
        override
        onlyOperatorManager
    {
        AccountTypes.Account storage account = userLedger[trade.accountId];
        account.lastPerpTradeId = trade.tradeId;
        // TODO update account.prep_position
    }

    function executeWithdrawAction(PrepTypes.WithdrawData calldata withdraw, uint256 eventId)
        public
        override
        onlyOperatorManager
    {}

    function executeSettlement(PrepTypes.Settlement calldata settlement, uint256 eventId)
        public
        override
        onlyOperatorManager
    {
        // check total settle amount zero
        int256 totalSettleAmount = 0;
        // gas saving
        uint256 length = settlement.settlementExecutions.length;
        PrepTypes.SettlementExecution[] calldata settlementExecutions = settlement.settlementExecutions;
        for (uint256 i = 0; i < length; ++i) {
            totalSettleAmount += settlementExecutions[i].settledAmount;
        }
        require(totalSettleAmount == 0, "total settle amount not zero");

        AccountTypes.Account storage account = userLedger[settlement.accountId];
        uint256 balance = account.balance;
        account.hasPendingSettlementRequest = false;
        if (settlement.insuranceTransferAmount != 0) {
            // transfer insurance fund
            if (int256(account.balance) + int256(settlement.insuranceTransferAmount) + settlement.settledAmount < 0) {
                // overflow
                revert("Insurance transfer amount invalid");
            }
            AccountTypes.Account storage insuranceFund = userLedger[insuranceFundAccountId];
            insuranceFund.balance += settlement.insuranceTransferAmount;
        }
        // for-loop settlement execution
        for (uint256 i = 0; i < length; ++i) {
            PrepTypes.SettlementExecution calldata settlementExecution = settlementExecutions[i];
            AccountTypes.PerpPosition storage position = account.perpPosition;
            if (position.positionQty != 0) {
                AccountTypes.chargeFundingFee(position, settlementExecution.sumUnitaryFundings);
                position.cost_position += settlementExecution.settledAmount;
                position.last_executed_price = settlementExecution.markPrice;
            }
            // check balance + settledAmount >= 0, where balance should cast to int256 first
            require(int256(balance) + settlementExecution.settledAmount >= 0, "balance not enough");
            balance = uint256(int256(balance) + settlementExecution.settledAmount);
        }
        account.lastCefiEventId = eventId;
    }

    function executeLiquidation(PrepTypes.Liquidation calldata liquidation, uint256 eventId)
        public
        override
        onlyOperatorManager
    {
        AccountTypes.Account storage liquidated_user = userLedger[liquidation.accountId];
        // for-loop liquidation execution
        uint256 length = liquidation.liquidationTransfers.length;
        PrepTypes.LiquidationTransfer[] calldata liquidationTransfers = liquidation.liquidationTransfers;
        // chargeFundingFee for liquidated_user.perpPosition
        for (uint256 i = 0; i < length; ++i) {
            AccountTypes.chargeFundingFee(liquidated_user.perpPosition, liquidationTransfers[i].sumUnitaryFundings);
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

    function _check_cefi_down() internal pure returns (bool) {
        // TODO mock here
        return true;
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

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./interface/Isettlement.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * Settlement is responsible for saving traders' Account (balance, perp_position, and other meta)
 * and global state (e.g. futures_upload_batch_id)
 * This contract should only have one in main-chain (avalanche)
 */
contract Settlement is Ownable, Isettlement {
    // OperatorManager contract address
    address public operator_manager_address;
    // global_withdraw_id
    uint256 public global_withdraw_id;
    // operator_trades_batch_id
    uint256 public operator_trades_batch_id;
    // global_event_id
    uint256 public global_event_id;
    // user_ledger
    mapping(bytes32 => AccountTypes.Account) private user_ledger;
    // insurance_fund
    bytes32 private insurance_fund;

    // require operator
    modifier onlyOperatorManager() {
        require(msg.sender == operator_manager_address, "only operator can call");
        _;
    }

    // set operator_manager_address
    function set_operator_manager_address(address _operator_manager_address) public onlyOwner {
        operator_manager_address = _operator_manager_address;
    }

    // set insurance_fund
    function set_insurance_fund(bytes32 _insurance_fund) public onlyOwner {
        insurance_fund = _insurance_fund;
    }

    // Interface implementation

    function register_account(bytes32 account_id, address addr, uint256 broker_id)
        public
        override
        onlyOperatorManager
    {
        // TODO
    }

    function update_user_ledger_by_trade_upload(PrepTypes.FuturesTradeUpload calldata trade)
        public
        override
        onlyOperatorManager
    {
        AccountTypes.Account storage account = user_ledger[trade.account_id];
        account.last_perp_trade_id = trade.trade_id;
        // TODO update account.prep_position
    }

    function execute_withdraw_action(PrepTypes.WithdrawData calldata withdraw, uint256 event_id)
        public
        override
        onlyOperatorManager
    {}

    function execute_settlement(PrepTypes.Settlement calldata settlement, uint256 event_id)
        public
        override
        onlyOperatorManager
    {
        // check total settle amount zero
        int256 totalSettleAmount = 0;
        // gas saving
        uint256 length = settlement.settlement_executions.length;
        PrepTypes.SettlementExecution[] calldata settlement_executions = settlement.settlement_executions;
        for (uint256 i = 0; i < length; ++i) {
            totalSettleAmount += settlement_executions[i].settled_amount;
        }
        require(totalSettleAmount == 0, "total settle amount not zero");

        //
        AccountTypes.Account storage account = user_ledger[settlement.account_id];
        uint256 balance = account.balance;
        account.has_pending_settlement_request = false;
        if (settlement.insurance_transfer_amount != 0) {
            // transfer insurance fund
            if (int256(account.balance) + int256(settlement.insurance_transfer_amount) + settlement.settled_amount < 0)
            {
                // overflow
                revert("Insurance transfer amount invalid");
            }
            AccountTypes.Account storage insuranceFund = user_ledger[insurance_fund];
            insuranceFund.balance += settlement.insurance_transfer_amount;
        }
        // for-loop settlement execution
        for (uint256 i = 0; i < length; ++i) {
            PrepTypes.SettlementExecution calldata settlementExecution = settlement_executions[i];
            AccountTypes.PerpPosition storage position = account.perp_position;
            if (position.position_qty != 0) {
                AccountTypes.chargeFundingFee(position, settlementExecution.sum_unitary_fundings);
                position.cost_position += settlementExecution.settled_amount;
                position.last_executed_price = settlementExecution.mark_price;
            }
            // check balance + settled_amount >= 0, where balance should cast to int256 first
            require(int256(balance) + settlementExecution.settled_amount >= 0, "balance not enough");
            balance = uint256(int256(balance) + settlementExecution.settled_amount);
        }
        account.last_cefi_event_id = event_id;
    }

    function execute_liquidation(PrepTypes.Liquidation calldata liquidation, uint256 event_id)
        public
        override
        onlyOperatorManager
    {
        AccountTypes.Account storage liquidated_user = user_ledger[liquidation.account_id];
        // for-loop liquidation execution
        uint256 length = liquidation.liquidation_transfers.length;
        PrepTypes.LiquidationTransfer[] calldata liquidation_transfers = liquidation.liquidation_transfers;
        // chargeFundingFee for liquidated_user.perp_position
        for (uint256 i = 0; i < length; ++i) {
            AccountTypes.chargeFundingFee(liquidated_user.perp_position, liquidation_transfers[i].sum_unitary_fundings);
        }
        // TODO get_liquidation_info
        // TODO transfer_liquidated_asset_to_insurance if insurance_transfer_amount != 0
        for (uint256 i = 0; i < length; ++i) {
            // TODO liquidator_liquidate_and_update_event_id
            // TODO liquidated_user_liquidate
            // TODO insurance_liquidate
        }
        liquidated_user.last_cefi_event_id = event_id;
        // TODO emit event
    }

    function _check_cefi_down() internal pure returns (bool) {
        // TODO mock here
        return true;
    }

    function _new_global_event_id() internal returns (uint256) {
        global_event_id += 1;
        return global_event_id;
    }

    function _new_withdraw_id() internal returns (uint256) {
        global_withdraw_id += 1;
        return global_withdraw_id;
    }
}

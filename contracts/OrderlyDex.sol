// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import './interface/IOrderlyDex.sol';
import './library/types.sol';

/**
 * OrderlyDex is responsible for saving traders' Account (balance, perp_position, and other meta)
 * and global state (e.g. futures_upload_batch_id)
 * This contract should only have one in main-chain (avalanche)
 */
contract OrderlyDex is IOrderlyDex {
    // OperatorManager contract address
    address public operator_manager_address;
    // user_ledger
    mapping (address => Account) public user_ledger;

    // admin address
    address public admin;

    // constructor
    constructor(address _admin) {
        admin = _admin;
    }

    // require operator
    modifier only_operator_manager() {
        require(msg.sender == operator_manager_address, "only operator can call");
        _;
    }

    // require admin
    modifier only_admin() {
        require(msg.sender == admin, "only admin can call");
        _;
    }

    // set operator_manager_address
    function set_operator_manager_address(address _operator_manager_address) public only_admin {
        operator_manager_address = _operator_manager_address;
    }

    // update user ledger by trade upload
    function update_user_ledger_by_trade_upload(Types.FuturesTradeUpload calldata trade) public only_operator_manager {
        Account storage account = user_ledger[trade.account_id];
        account.last_perp_trade_id = trade.trade_id;
        // TODO update account.prep_position
    }

    // execute_withdraw_action
    function execute_withdraw_action(Types.WithdrawData calldata withdraw, uint event_id) public only_operator_manager {
        // TODO
        if (withdraw.approval) {
            _operator_withdraw_approve(withdraw, event_id);
        } else {
            _operator_reject_withdraw_request(withdraw, event_id);
        }
    }

    // execute_settlement
    function execute_settlement(Types.Settlement calldata settlement, uint event_id) public only_operator_manager {
        // TODO
    }

    // execute_liquidation
    function execute_liquidation(Types.Liquidation calldata liquidation, uint event_id) public only_operator_manager {
        // TODO
    }

    // operator_withdraw_approve
    function _operator_withdraw_approve(Types.WithdrawData calldata withdraw, uint event_id) internal {
        // TODO
        // Account storage account = user_ledger[withdraw.account_id];

    }

    // operator_reject_withdraw_request
    function _operator_reject_withdraw_request(Types.WithdrawData calldata withdraw, uint event_id) internal {
        // TODO
    }
}
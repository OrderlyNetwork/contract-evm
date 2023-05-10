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

    // require operator
    modifier onlyOperatorManager() {
        require(msg.sender == operator_manager_address, "only operator can call");
        _;
    }

    // set operator_manager_address
    function set_operator_manager_address(address _operator_manager_address) public onlyOwner {
        operator_manager_address = _operator_manager_address;
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
        // TODO send cross-chain tx to target vault
    }

    function execute_liquidation(PrepTypes.Liquidation calldata liquidation, uint256 event_id)
        public
        override
        onlyOperatorManager
    {
        // TODO
        // AccountTypes.Account storage liquidated_user = user_ledger[liquidation.account_id];
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

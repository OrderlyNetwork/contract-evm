// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./interface/IERC20.sol";

/**
 * AssetManager is responsible for saving user's USDC (where USDC which is a IERC20 token).
 * EACH CHAIN SHOULD HAVE ONE ASSETMANAGER CONTRACT.
 * User can deposit and withdraw USDC from AssetManager.
 * Only xchain_operator can approve withdraw request.
 */
contract AssetManager {
    // cross-chain operator address
    address public xchain_operator;
    // USDC contract
    IERC20 public usdc;
    // user's USDC balance (maybe not need this)
    mapping(address => uint256) public user_balance;
    // user's pending_withdraw USDC balance
    mapping(address => WithdrawInfo) public pending_withdraw_info;
    // nonReentrant lock
    bool nonReentrantLock = false;

    event deposit_event(address user, uint256 amount);
    event withdraw_event(address user, uint256 amount, uint256 withdraw_id);
    event withdraw_approve_event(address user, uint256 amount, uint256 withdraw_id, uint256 event_id);
    event withdraw_reject_event(address user, uint256 withdraw_id, uint256 event_id);

    struct WithdrawRequest {
        uint256 amount;
        uint256 request_time;
        uint256 withdraw_id;
        uint256 event_id;
    }

    struct WithdrawInfo {
        uint256 pending_withdraw;
        uint256 last_event_id;
        mapping(uint256 => WithdrawRequest) withdraw_requests;
    }

    // only cross-chain operator can call
    modifier only_xchain_operator() {
        require(msg.sender == xchain_operator, "only operator can call");
        _;
    }

    // nonReentrant
    modifier nonReentrant() {
        require(!nonReentrantLock, "nonReentrant");
        nonReentrantLock = true;
        _;
        nonReentrantLock = false;
    }

    constructor(address usdc_address, address _xchain_operator) {
        usdc = IERC20(usdc_address);
        xchain_operator = _xchain_operator;
    }

    // user deposit USDC
    function deposit(uint256 amount) public {
        require(usdc.transferFrom(msg.sender, address(this), amount), "transferFrom failed");
        user_balance[msg.sender] += amount;
        // emit deposit event
        emit deposit_event(msg.sender, amount);
    }

    // user withdraw USDC by withdraw_id
    function withdraw(uint256 withdraw_id) public nonReentrant {
        WithdrawInfo storage withdraw_info = pending_withdraw_info[msg.sender];
        WithdrawRequest storage withdraw_request = withdraw_info.withdraw_requests[withdraw_id];
        require(withdraw_request.amount > 0, "withdraw request not found");
        // transfer USDC to user
        require(usdc.transfer(msg.sender, withdraw_request.amount), "transfer failed");
        // update pending_withdraw
        withdraw_info.pending_withdraw -= withdraw_request.amount;
        // delete finished withdraw request
        delete withdraw_info.withdraw_requests[withdraw_id];
        // emit withdraw event
        emit withdraw_event(msg.sender, withdraw_request.amount, withdraw_id);
    }

    // user withdraw USDC by withdraw_ids
    function withdraws(uint256[] memory withdraw_ids) public nonReentrant {
        // TODO batch withdraw. Pay attention to the reentrancy problem.
    }

    // withdraw approve
    // Cefi send withdraw approve event to OperatorManager,
    // and the message should cross-chain by xchain-operator,
    // finally call this function to approve withdraw request
    function withdraw_approve(address user, uint256 amount, uint256 request_time, uint256 withdraw_id, uint256 event_id)
        public
        only_xchain_operator
        nonReentrant
    {
        require(user_balance[user] >= amount, "insufficient balance");
        user_balance[user] -= amount;
        // TODO get withdraw_info by user. if not exist, create a new one
        WithdrawInfo storage withdraw_info = pending_withdraw_info[user];
        // new withdraw_requests, and save it to withdraw_info
        WithdrawRequest memory wr = WithdrawRequest(amount, request_time, withdraw_id, event_id);
        withdraw_info.withdraw_requests[withdraw_id] = wr;
        // update pending_withdraw
        withdraw_info.pending_withdraw += amount;
        // emit withdraw approve event
        emit withdraw_approve_event(user, amount, withdraw_id, event_id);
    }

    // withdraw reject
    function withdraw_reject(address user, uint256 withdraw_id, uint256 event_id)
        public
        only_xchain_operator
        nonReentrant
    {
        // emit withdraw reject event
        emit withdraw_reject_event(user, withdraw_id, event_id);
    }
}

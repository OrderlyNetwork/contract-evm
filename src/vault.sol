// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

/**
 * Vault is responsible for saving user's USDC (where USDC which is a IERC20 token).
 * EACH CHAIN SHOULD HAVE ONE Vault CONTRACT.
 * User can deposit and withdraw USDC from Vault.
 * Only xchain_operator can approve withdraw request.
 */
contract Vault is ReentrancyGuard {
    event deposit_event(address user, uint256 amount);
    event withdraw_event(address user, uint256 amount);

    // cross-chain operator address
    address public xchain_operator;
    // USDC contract
    IERC20 public usdc;

    // only cross-chain operator can call
    modifier onlyXchainOperator() {
        require(msg.sender == xchain_operator, "only operator can call");
        _;
    }

    constructor(address usdc_address, address _xchain_operator) {
        usdc = IERC20(usdc_address);
        xchain_operator = _xchain_operator;
    }

    // user deposit USDC
    function deposit(uint256 amount) public {
        require(usdc.transferFrom(msg.sender, address(this), amount), "transferFrom failed");
        // emit deposit event
        emit deposit_event(msg.sender, amount);
        // TODO send cross-chain tx to settlement
    }

    // user withdraw USDC
    function withdraw(uint256 amount) public onlyXchainOperator nonReentrant {
        // check USDC balane gt amount
        require(usdc.balanceOf(address(this)) >= amount, "balance not enough");
        // transfer USDC to user
        require(usdc.transfer(msg.sender, amount), "transfer failed");
        // emit withdraw event
        emit withdraw_event(msg.sender, amount);
    }
}

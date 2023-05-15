// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * Vault is responsible for saving user's USDC (where USDC which is a IERC20 token).
 * EACH CHAIN SHOULD HAVE ONE Vault CONTRACT.
 * User can deposit and withdraw USDC from Vault.
 * Only xchainOperator can approve withdraw request.
 */
contract Vault is ReentrancyGuard, Ownable {
    event DepositEvent(address user, uint256 amount);
    event WithdrawEvent(address user, uint256 amount);

    // cross-chain operator address
    address public xchainOperator;
    // USDC contract
    IERC20 public usdc;

    // only cross-chain operator can call
    modifier onlyXchainOperator() {
        require(msg.sender == xchainOperator, "only operator can call");
        _;
    }

    // change xchainOperator
    function setXchainOperator(address _xchainOperator) public onlyOwner {
        xchainOperator = _xchainOperator;
    }

    constructor(address usdc_address, address _xchainOperator) {
        usdc = IERC20(usdc_address);
        xchainOperator = _xchainOperator;
    }

    // user deposit USDC
    function deposit(uint256 amount) public {
        require(usdc.transferFrom(msg.sender, address(this), amount), "transferFrom failed");
        // emit deposit event
        emit DepositEvent(msg.sender, amount);
        // TODO send cross-chain tx to settlement
    }

    // user withdraw USDC
    function withdraw(uint256 amount) public onlyXchainOperator nonReentrant {
        // check USDC balane gt amount
        require(usdc.balanceOf(address(this)) >= amount, "balance not enough");
        // transfer USDC to user
        require(usdc.transfer(msg.sender, amount), "transfer failed");
        // emit withdraw event
        emit WithdrawEvent(msg.sender, amount);
    }
}

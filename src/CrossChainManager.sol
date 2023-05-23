// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./interface/ISettlement.sol";
import "./interface/ICrossChainManager.sol";
import "./interface/IOperatorManager.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * CrossChainManager is responsible for executing cross-chain tx.
 * This contract should only have one in main-chain (avalanche)
 */
contract CrossChainManager is ICrossChainManager, Ownable {
    // cross-chain operator address
    address public xchainOperator;
    // settlement Interface
    ISettlement public settlement;
    // operatorManager Interface
    IOperatorManager public operatorManager;

    // only xchain operator
    modifier onlyXchainOperator() {
        require(msg.sender == xchainOperator, "only xchain operator can call");
        _;
    }

    // set xchainOperator
    function setXchainOperator(address _xchainOperator) public onlyOwner {
        xchainOperator = _xchainOperator;
    }

    // set settlement
    function setSettlement(address _settlement) public onlyOwner {
        settlement = ISettlement(_settlement);
    }

    // set operatorManager
    function setOperatorManager(address _operatorManager) public onlyOwner {
        operatorManager = IOperatorManager(_operatorManager);
    }

    // constructor
    constructor(address _xchainOperator) {
        xchainOperator = _xchainOperator;
    }

    // cross-chain operator deposit
    function crossChainOperatorExecuteAction(
        OperatorTypes.CrossChainOperatorActionData actionData,
        bytes calldata action
    ) public override onlyXchainOperator {
        if (actionData == OperatorTypes.CrossChainOperatorActionData.UserDeposit) {
            // UserDeposit
            settlement.accountDeposit(abi.decode(action, (AccountTypes.AccountDeposit)));
        } else if (actionData == OperatorTypes.CrossChainOperatorActionData.UserEmergencyWithdraw) {
            // UserEmergencyWithdraw iff cefi down
            require(operatorManager.checkCefiDown(), "cefi not down");
            // TODO
            // settlement.accountEmergencyWithdraw(abi.decode(action, (PrepTypes.WithdrawData)));
        } else {
            revert("invalid action data");
        }
    }
}

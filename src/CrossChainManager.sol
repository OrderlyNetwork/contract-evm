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
    // settlement Interface
    ISettlement public settlement;
    // operatorManager Interface
    IOperatorManager public operatorManager;

    // set settlement
    function setSettlement(address _settlement) public onlyOwner {
        settlement = ISettlement(_settlement);
    }

    // set operatorManager
    function setOperatorManager(address _operatorManager) public onlyOwner {
        operatorManager = IOperatorManager(_operatorManager);
    }

    // cross-chain operator deposit
    // TODO should be removed
    function crossChainOperatorExecuteAction(
        OperatorTypes.CrossChainOperatorActionData actionData,
        bytes calldata action
    ) public override onlyOwner {
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

    function deposit(CrossChainMessageTypes.MessageV1 calldata message) public override onlyOwner {
        // convert message to AccountTypes.AccountDeposit
        AccountTypes.AccountDeposit memory data = AccountTypes.AccountDeposit({
            accountId: message.accountId,
            addr: message.addr,
            symbol: message.tokenSymbol,
            amount: message.tokenAmount,
            chainId: message.srcChainId
        });
        settlement.accountDeposit(data);
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./interface/ILedger.sol";
import "./interface/ILedgerCrossChainManager.sol";
import "./interface/IOperatorManager.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "crosschain/interface/IOrderlyCrossChain.sol";
import "crosschain/utils/OrderlyCrossChainMessage.sol";
import "./library/types/AccountTypes.sol";
import "./library/types/EventTypes.sol";
import "./library/types/VaultTypes.sol";

/**
 * CrossChainManager is responsible for executing cross-chain tx.
 * This contract should only have one in main-chain (avalanche)
 *
 * Ledger(manager addr, chain id) -> LedgerCrossChainManager -> OrderlyCrossChain -> VaultCrossChainManager(Identified by chain id) -> Vault
 *
 */
contract LedgerCrossChainManager is
    IOrderlyCrossChainReceiver,
    ILedgerCrossChainManager,
    Ownable
{

    event DepositReceived(AccountTypes.AccountDeposit data);

    // chain id of this contract
    uint256 public chainId;
    // ledger Interface
    ILedger public ledger;
    // crosschain relay interface
    IOrderlyCrossChain public crossChainRelay;
    // operatorManager Interface
    IOperatorManager public operatorManager;
    // map of chainId => VaultCrossChainManager
    mapping(uint256 => address) public vaultCrossChainManagers;

    // set chain id
    function setChainId(uint256 _chainId) public {
        chainId = _chainId;
    }

    // set ledger
    function setLedger(address _ledger) public {
        ledger = ILedger(_ledger);
    }

    // set crossChainRelay
    function setCrossChainRelay(address _crossChainRelay) public {
        crossChainRelay = IOrderlyCrossChain(_crossChainRelay);
    }

    // set operatorManager
    function setOperatorManager(address _operatorManager) public onlyOwner {
        operatorManager = IOperatorManager(_operatorManager);
    }

    // set vaultCrossChainManager
    function setVaultCrossChainManager(
        uint256 _chainId,
        address _vaultCrossChainManager
    ) public onlyOwner {
        vaultCrossChainManagers[_chainId] = _vaultCrossChainManager;
    }

    function deposit(
        AccountTypes.AccountDeposit memory data) internal {
        emit DepositReceived(data);
        ledger.accountDeposit(data);
    }

    function receiveMessage(
        OrderlyCrossChainMessage.MessageV1 memory message,
        bytes memory payload
    ) external override {
        require(
            msg.sender == address(crossChainRelay),
            "LedgerCrossChainManager: only crossChainRelay can call"
        );
        require(
            message.dstChainId == chainId,
            "LedgerCrossChainManager: dstChainId not match"
        );
        if (message.payloadDataType == uint8(
            OrderlyCrossChainMessage.PayloadDataType.VaultTypesVaultDeposit
        )) {
            VaultTypes.VaultDeposit memory data = abi.decode(
                payload,
                (VaultTypes.VaultDeposit)
            );

            AccountTypes.AccountDeposit memory depositData = AccountTypes.AccountDeposit({
                accountId: data.accountId,
                brokerHash: data.brokerHash,
                userAddress: data.userAddress,
                tokenHash: data.tokenHash,
                tokenAmount: data.tokenAmount,
                srcChainId: message.srcChainId,
                srcChainDepositNonce: data.depositNonce
            });

            deposit(depositData);

        } else if (message.payloadDataType == uint8(
            OrderlyCrossChainMessage.PayloadDataType.VaultTypesVaultWithdraw
        )) {
            VaultTypes.VaultWithdraw memory data = abi.decode(
                payload,
                (VaultTypes.VaultWithdraw)
            );

            AccountTypes.AccountWithdraw memory withdrawData = AccountTypes.AccountWithdraw({
                accountId: data.accountId,
                sender: data.sender,
                receiver: data.receiver,
                brokerHash: data.brokerHash,
                tokenHash: data.tokenHash,
                tokenAmount: data.tokenAmount,
                fee: data.fee,
                chainId: message.srcChainId,
                withdrawNonce: data.withdrawNonce
            });

            withdrawFinish(withdrawData);
        } else {
            revert("LedgerCrossChainManager: payloadDataType not match");
        }
    }


    function withdraw(
        EventTypes.WithdrawData calldata data
    ) external override {
        // only ledger can call this function
        require(msg.sender == address(ledger), "caller is not ledger");

        OrderlyCrossChainMessage.MessageV1
            memory message = OrderlyCrossChainMessage.MessageV1({
                method: uint8(OrderlyCrossChainMessage.CrossChainMethod.Withdraw),
                option: uint8(OrderlyCrossChainMessage.CrossChainOption.LayerZero),
                payloadDataType: uint8(OrderlyCrossChainMessage.PayloadDataType.EventTypesWithdrawData),
                srcCrossChainManager: address(this),
                dstCrossChainManager: vaultCrossChainManagers[data.chainId],
                srcChainId: chainId,
                dstChainId: data.chainId
            });
        bytes memory payload = abi.encode(data);

        crossChainRelay.sendMessage(message, payload);
    }

    function withdrawFinish(
        AccountTypes.AccountWithdraw memory message
    ) internal {
        ledger.accountWithDrawFinish(message);
    }
}

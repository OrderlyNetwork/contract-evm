// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./interface/IVault.sol";
import "./interface/IVaultCrossChainManager.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "crosschain/interface/IOrderlyCrossChain.sol";
import "crosschain/utils/OrderlyCrossChainMessage.sol";
import "./library/types/VaultTypes.sol";
import "./library/types/EventTypes.sol";
import "./library/Utils.sol";

contract VaultCrossChainManager is IOrderlyCrossChainReceiver, IVaultCrossChainManager, Ownable {
    // src chain id
    uint256 public chainId;
    // ledger chain id
    uint256 public ledgerChainId;
    // vault interface
    IVault public vault;
    // crosschain relay interface
    IOrderlyCrossChain public crossChainRelay;
    // map of chainId => LedgerCrossChainManager
    mapping(uint256 => address) public ledgerCrossChainManagers;

    // set chain id
    function setChainId(uint256 _chainId) public {
        chainId = _chainId;
    }

    // set vault
    function setVault(address _vault) public {
        vault = IVault(_vault);
    }

    // set crossChainRelay
    function setCrossChainRelay(address _crossChainRelay) public {
        crossChainRelay = IOrderlyCrossChain(_crossChainRelay);
    }

    // set ledgerCrossChainManager
    function setLedgerCrossChainManager(uint256 _chainId, address _ledgerCrossChainManager) public {
        ledgerChainId = _chainId;
        ledgerCrossChainManagers[_chainId] = _ledgerCrossChainManager;
    }

    function receiveMessage(OrderlyCrossChainMessage.MessageV1 memory message, bytes memory payload)
        external
        override
    {
        require(msg.sender == address(crossChainRelay), "VaultCrossChainManager: only crossChainRelay can call");
        require(message.dstChainId == chainId, "VaultCrossChainManager: dstChainId not match");

        EventTypes.WithdrawData memory data = abi.decode(payload, (EventTypes.WithdrawData));

        VaultTypes.VaultWithdraw memory withdrawData = VaultTypes.VaultWithdraw({
            accountId: data.accountId,
            sender: data.sender,
            receiver: data.receiver,
            brokerHash: Utils.string2HashedBytes32(data.brokerId),
            tokenHash: Utils.string2HashedBytes32(data.tokenSymbol),
            tokenAmount: data.tokenAmount,
            fee: data.fee,
            withdrawNonce: data.withdrawNonce
        });

        sendWithdrawToVault(withdrawData);
    }

    // user withdraw USDC
    function sendWithdrawToVault(VaultTypes.VaultWithdraw memory data) internal {
        vault.withdraw(data);
    }

    function deposit(VaultTypes.VaultDeposit memory data) external override {
        OrderlyCrossChainMessage.MessageV1 memory message = OrderlyCrossChainMessage.MessageV1({
            method: uint8(OrderlyCrossChainMessage.CrossChainMethod.Deposit),
            option: uint8(OrderlyCrossChainMessage.CrossChainOption.LayerZero),
            payloadDataType: uint8(OrderlyCrossChainMessage.PayloadDataType.VaultTypesVaultDeposit),
            srcCrossChainManager: address(this),
            dstCrossChainManager: ledgerCrossChainManagers[ledgerChainId],
            srcChainId: chainId,
            dstChainId: ledgerChainId
        });
        // encode message
        bytes memory payload = abi.encode(data);

        crossChainRelay.sendMessage(message, payload);
    }

    function withdraw(VaultTypes.VaultWithdraw memory data) external override {
        OrderlyCrossChainMessage.MessageV1 memory message = OrderlyCrossChainMessage.MessageV1({
            method: uint8(OrderlyCrossChainMessage.CrossChainMethod.WithdrawFinish),
            option: uint8(OrderlyCrossChainMessage.CrossChainOption.LayerZero),
            payloadDataType: uint8(OrderlyCrossChainMessage.PayloadDataType.VaultTypesVaultWithdraw),
            srcCrossChainManager: address(this),
            dstCrossChainManager: ledgerCrossChainManagers[ledgerChainId],
            srcChainId: chainId,
            dstChainId: ledgerChainId
        });
        // encode message
        bytes memory payload = abi.encode(data);

        crossChainRelay.sendMessage(message, payload);
    }
}

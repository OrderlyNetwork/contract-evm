// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./interface/IVault.sol";
import "./interface/IVaultCrossChainManager.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "crosschain/interface/IOrderlyCrossChain.sol";
import "crosschain/utils/OrderlyCrossChainMessage.sol";

contract VaultCrossChainManager is
    IOrderlyCrossChainReceiver,
    IVaultCrossChainManager,
    Ownable
{
    // src chain id
    uint256 public chainId;
    // vault interface
    IVault public vault;
    // crosschain relay interface
    IOrderlyCrossChain public crossChainRelay;
    // map of chainId => LedgerCrossChainManager
    mapping(uint256 => address) public ledgerCrossChainManagers;

    // set chain id
    function setChainId(uint256 _chainId) public onlyOwner {
        chainId = _chainId;
    }

    // set vault
    function setVault(address _vault) public onlyOwner {
        vault = IVault(_vault);
    }

    // set crossChainRelay
    function setCrossChainRelay(address _crossChainRelay) public onlyOwner {
        crossChainRelay = IOrderlyCrossChain(_crossChainRelay);
    }

    // set ledgerCrossChainManager
    function setLedgerCrossChainManager(
        uint256 _chainId,
        address _ledgerCrossChainManager
    ) public onlyOwner {
        ledgerCrossChainManagers[_chainId] = _ledgerCrossChainManager;
    }

    function receiveMessage(
        bytes calldata payload,
        uint256 srcChainId,
        uint256 dstChainId
    ) external override {
        emit MessageReceived(payload, srcChainId, dstChainId);
        // only relay can call it
        require(
            msg.sender == address(crossChainRelay),
            "VaultCrossChainManager: receiveMessage caller is not crossChainRelay"
        );

        OrderlyCrossChainMessage.MessageV1
            memory message = OrderlyCrossChainMessage.decodeMessageV1(payload);
        withdraw(message);
    }

    // user withdraw USDC
    function withdraw(
        OrderlyCrossChainMessage.MessageV1 memory message
    ) public override onlyOwner {
        // VaultTypes.VaultWithdraw memory data = VaultTypes.VaultWithdraw(
        //     message.accountId,
        //     message.userAddress,
        //     message.tokenSymbol,
        //     message.tokenAmount
        // );
        // vault.withdraw(data);
    }

    function deposit(
        AccountTypes.AccountDeposit calldata data
    ) external override {
        // only vault can call
        require(
            msg.sender == address(vault),
            "VaultCrossChainManager: deposit caller is not vault"
        );

        // TODO broker id
        uint256 brokerId = 123;

        OrderlyCrossChainMessage.MessageV1
            memory message = OrderlyCrossChainMessage.MessageV1({
                version: 1,
                method: uint8(OrderlyCrossChainMessage.CrossChainMethod.Deposit),
                userAddress: data.userAddress,
                srcChainId: chainId,
                dstChainId: data.srcChainId,
                accountId: data.accountId,
                brokerId: bytes32(brokerId), // TODO broker id
                tokenSymbol: data.tokenSymbol,
                tokenAmount: data.tokenAmount
            });
        // encode message
        bytes memory payload = OrderlyCrossChainMessage.encodeMessageV1(message);

        // send message to ledgerCrossChainManager
        crossChainRelay.sendMessage(
            payload,
            chainId,
            data.srcChainId
        );
    }
}

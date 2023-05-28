// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./interface/IVault.sol";
import "./interface/IVaultCrossChainManager.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./crossChain/interface/IOrderlyCrossChain.sol";
import "./crossChain/utils/OrderlyCrossChainMessage.sol";

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
    // map of chainId => SettlementCrossChainManager
    mapping(uint256 => address) public settlementCrossChainManagers;

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

    // set settlementCrossChainManager
    function setSettlementCrossChainManager(
        uint256 _chainId,
        address _settlementCrossChainManager
    ) public onlyOwner {
        settlementCrossChainManagers[_chainId] = _settlementCrossChainManager;
    }

    function receiveMessage(
        bytes memory payload,
        uint256 srcChainId,
        uint256 dstChainId,
        address contractAddress
    ) external override {
        // only relay can call it
        require(
            msg.sender == address(crossChainRelay),
            "VaultCrossChainManager: receiveMessage caller is not crossChainRelay"
        );

        OrderlyCrossChainMessage.MessageV1
            memory message = OrderlyCrossChainMessage.arrayToMsg(
                OrderlyCrossChainMessage.decodePacked(payload)
            );
        withdraw(message);
    }

    // user withdraw USDC
    function withdraw(
        OrderlyCrossChainMessage.MessageV1 calldata message
    ) public override onlyOwner {
        vault.withdraw(
            message.accountId,
            message.addr,
            message.tokenSymbol,
            message.tokenAmount
        );
    }

    function deposit(
        AccountTypes.AccountDeposit calldata data
    ) external override {
        // only vault can call
        require(
            msg.sender == address(vault),
            "VaultCrossChainManager: deposit caller is not vault"
        );
        OrderlyCrossChainMessage.MessageV1
            memory message = OrderlyCrossChainMessage.MessageV1({
                version: 1,
                userAddress: data.addr,
                srcChainId: chainId,
                dstChainId: data.chainId,
                method: "withdraw",
                accountId: data.accountId,
                tokenSymbol: data.symbol,
                tokenAmount: data.amount
            });
        // encode message
        bytes calldata payload = OrderlyCrossChainMessage.encodePacked(
            OrderlyCrossChainMessage.msgToArray(message)
        );

        // send message to settlementCrossChainManager
        crossChainRelay.sendMessage(
            payload,
            chainId,
            data.chainId,
            settlementCrossChainManagers[data.chainId]
        );
    }
}

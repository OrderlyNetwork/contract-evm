// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./interface/ISettlement.sol";
import "./interface/ISettlementCrossChainManager.sol";
import "./interface/IOperatorManager.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "crosschain/interface/IOrderlyCrossChain.sol";
import "crosschain/utils/OrderlyCrossChainMessage.sol";
import "./library/types/AccountTypes.sol";
import "./library/types/PerpTypes.sol";

/**
 * CrossChainManager is responsible for executing cross-chain tx.
 * This contract should only have one in main-chain (avalanche)
 *
 * Settlement(manager addr, chain id) -> SettlementCrossChainManager -> OrderlyCrossChain -> VaultCrossChainManager(Identified by chain id) -> Vault
 *
 */
contract SettlementCrossChainManager is
    IOrderlyCrossChainReceiver,
    ISettlementCrossChainManager,
    Ownable
{
    // chain id of this contract
    uint256 public chainId;
    // settlement Interface
    ISettlement public settlement;
    // crosschain relay interface
    IOrderlyCrossChain public crossChainRelay;
    // operatorManager Interface
    IOperatorManager public operatorManager;
    // map of chainId => VaultCrossChainManager
    mapping(uint256 => address) public vaultCrossChainManagers;

    // set chain id
    function setChainId(uint256 _chainId) public onlyOwner {
        chainId = _chainId;
    }

    // set settlement
    function setSettlement(address _settlement) public onlyOwner {
        settlement = ISettlement(_settlement);
    }

    // set crossChainRelay
    function setCrossChainRelay(address _crossChainRelay) public onlyOwner {
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

    function receiveMessage(
        bytes calldata payload,
        uint256 srcChainId,
        uint256 dstChainId
    ) external override {
        emit MessageReceived(payload, srcChainId, dstChainId);
        require(
            msg.sender == address(crossChainRelay),
            "caller is not crossChainRelay"
        );
        // convert payload to CrossChainMessageTypes.MessageV1
        OrderlyCrossChainMessage.MessageV1
            memory message = OrderlyCrossChainMessage.decodeMessageV1(payload);
        // execute deposit
        deposit(message);
    }

    function deposit(
        OrderlyCrossChainMessage.MessageV1 memory message
    ) public override onlyOwner {
        // convert message to AccountTypes.AccountDeposit
        AccountTypes.AccountDeposit memory data = AccountTypes.AccountDeposit({
            accountId: message.accountId,
            addr: message.userAddress,
            symbol: message.tokenSymbol,
            amount: message.tokenAmount,
            chainId: message.srcChainId
        });
        settlement.accountDeposit(data);
    }

    function withdraw(
        PerpTypes.WithdrawData calldata data
    ) external override onlyOwner {
        // only settlement can call this function
        require(msg.sender == address(settlement), "caller is not settlement");

        // TODO temporary value
        uint256 brokerId = 123;

        // convert data to CrossChainMessageTypes.MessageV1
        OrderlyCrossChainMessage.MessageV1
            memory message = OrderlyCrossChainMessage.MessageV1({
                version: 1,
                method: uint8(OrderlyCrossChainMessage.CrossChainMethod.Withdraw),
                userAddress: data.addr,
                srcChainId: chainId,
                dstChainId: data.chainId,
                accountId: data.accountId,
                brokerId: bytes32(brokerId), // TODO (need to be changed
                tokenSymbol: data.symbol,
                tokenAmount: data.amount
            });
        // encode message
        bytes memory payload = OrderlyCrossChainMessage.encodeMessageV1(message);
        // send message
        crossChainRelay.sendMessage(
            payload,
            message.srcChainId,
            message.dstChainId
        );
    }
}

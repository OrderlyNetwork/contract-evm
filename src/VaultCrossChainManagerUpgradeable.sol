// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./interface/IVault.sol";
import "./interface/IVaultCrossChainManager.sol";
import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "crosschain/interface/IOrderlyCrossChain.sol";
import "crosschain/utils/OrderlyCrossChainMessage.sol";
import "./library/types/VaultTypes.sol";
import "./library/types/EventTypes.sol";
import "./library/Utils.sol";

contract VaultCrossChainManagerDatalayout {
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
}

contract VaultCrossChainManagerUpgradeable is
    IVaultCrossChainManager,
    IOrderlyCrossChainReceiver,
    OwnableUpgradeable,
    UUPSUpgradeable,
    VaultCrossChainManagerDatalayout
{
    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function upgradeTo(address newImplementation) public override onlyOwner {
        _upgradeToAndCallUUPS(newImplementation, new bytes(0), false);
    }

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
    function setLedgerCrossChainManager(uint256 _chainId, address _ledgerCrossChainManager) public onlyOwner {
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

        // if token is CrossChainManagerTest
        if (keccak256(bytes(data.tokenSymbol)) == keccak256(bytes("CrossChainManagerTest"))) {
            sendTestWithdrawBack();
        } else {
            VaultTypes.VaultWithdraw memory withdrawData = VaultTypes.VaultWithdraw({
                accountId: data.accountId,
                sender: data.sender,
                receiver: data.receiver,
                brokerHash: Utils.getBrokerHash(data.brokerId),
                tokenHash: Utils.getTokenHash(data.tokenSymbol),
                tokenAmount: data.tokenAmount,
                fee: data.fee,
                withdrawNonce: data.withdrawNonce
            });
            sendWithdrawToVault(withdrawData);
        }
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

    function sendTestWithdrawBack() internal {
        VaultTypes.VaultWithdraw memory data = VaultTypes.VaultWithdraw({
            accountId: bytes32(0),
            sender: address(0),
            receiver: address(0),
            brokerHash: bytes32(0),
            tokenHash: Utils.getTokenHash("CrossChainManagerTest"),
            tokenAmount: 0,
            fee: 0,
            withdrawNonce: 0
        });
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

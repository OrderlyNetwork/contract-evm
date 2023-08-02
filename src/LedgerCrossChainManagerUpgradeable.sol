// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import "./interface/ILedger.sol";
import "./interface/ILedgerCrossChainManager.sol";
import "./interface/IOperatorManager.sol";
import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/security/PausableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "crosschain/interface/IOrderlyCrossChain.sol";
import "crosschain/utils/OrderlyCrossChainMessage.sol";
import "./library/types/AccountTypes.sol";
import "./library/types/EventTypes.sol";
import "./library/types/VaultTypes.sol";

contract LedgerCrossChainManagerDatalayout {
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

    mapping(bytes32 => mapping(uint256 => uint256)) public tokenDecimalMapping;
}

contract DecimalManager is LedgerCrossChainManagerDatalayout {
    function setTokenDecimal(bytes32 tokenHash, uint256 tokenChainId, uint256 decimal) external {
        tokenDecimalMapping[tokenHash][tokenChainId] = decimal;
    }

    function getTokenDecimal(bytes32 tokenHash, uint256 tokenChainId) internal view returns (uint256) {
        return tokenDecimalMapping[tokenHash][tokenChainId];
    }

    function convertDecimal(uint256 tokenAmount, uint256 srcDecimal, uint256 dstDecimal)
        internal
        pure
        returns (uint256)
    {
        if (srcDecimal == dstDecimal) {
            return tokenAmount;
        } else if (srcDecimal > dstDecimal) {
            return tokenAmount / (10 ** (srcDecimal - dstDecimal));
        } else {
            return tokenAmount * (10 ** (dstDecimal - srcDecimal));
        }
    }

    function convertDecimal(
        uint256 tokenAmount,
        bytes32 tokenHash,
        uint256 srcChainId,
        uint256 dstChainId
    ) internal view returns (uint256) {
        uint256 srcDecimal = getTokenDecimal(tokenHash, srcChainId);
        uint256 dstDecimal = getTokenDecimal(tokenHash, dstChainId);
        return convertDecimal(tokenAmount, srcDecimal, dstDecimal);
    }
}

/**
 * CrossChainManager is responsible for executing cross-chain tx.
 * This contract should only have one in main-chain (avalanche)
 *
 * Ledger(manager addr, chain id) -> LedgerCrossChainManager -> OrderlyCrossChain -> VaultCrossChainManager(Identified by chain id) -> Vault
 *
 */
contract LedgerCrossChainManagerUpgradeable is
    IOrderlyCrossChainReceiver,
    ILedgerCrossChainManager,
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    LedgerCrossChainManagerDatalayout,
    DecimalManager
{
    event DepositReceived(AccountTypes.AccountDeposit data);

    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function upgradeTo(address newImplementation) public override onlyOwner onlyProxy {
        _upgradeToAndCallUUPS(newImplementation, new bytes(0), false);
    }

    // set chain id
    function setChainId(uint256 _chainId) external onlyOwner {
        chainId = _chainId;
    }

    // set ledger
    function setLedger(address _ledger) external onlyOwner {
        ledger = ILedger(_ledger);
    }

    // set crossChainRelay
    function setCrossChainRelay(address _crossChainRelay) external onlyOwner {
        crossChainRelay = IOrderlyCrossChain(_crossChainRelay);
    }

    // set operatorManager
    function setOperatorManager(address _operatorManager) external onlyOwner {
        operatorManager = IOperatorManager(_operatorManager);
    }

    // set vaultCrossChainManager
    function setVaultCrossChainManager(uint256 _chainId, address _vaultCrossChainManager) external onlyOwner {
        vaultCrossChainManagers[_chainId] = _vaultCrossChainManager;
    }

    function deposit(AccountTypes.AccountDeposit memory data) internal {
        emit DepositReceived(data);
        ledger.accountDeposit(data);
    }

    function receiveMessage(OrderlyCrossChainMessage.MessageV1 memory message, bytes memory payload)
        external
        override
    {
        require(msg.sender == address(crossChainRelay), "LedgerCrossChainManager: only crossChainRelay can call");
        require(message.dstChainId == chainId, "LedgerCrossChainManager: dstChainId not match");
        if (message.payloadDataType == uint8(OrderlyCrossChainMessage.PayloadDataType.VaultTypesVaultDeposit)) {
            VaultTypes.VaultDeposit memory data = abi.decode(payload, (VaultTypes.VaultDeposit));

            uint256 cvtTokenAmount = convertDecimal(data.tokenAmount, data.tokenHash, message.srcChainId, chainId);

            AccountTypes.AccountDeposit memory depositData = AccountTypes.AccountDeposit({
                accountId: data.accountId,
                brokerHash: data.brokerHash,
                userAddress: data.userAddress,
                tokenHash: data.tokenHash,
                tokenAmount: cvtTokenAmount,
                srcChainId: message.srcChainId,
                srcChainDepositNonce: data.depositNonce
            });

            deposit(depositData);
        } else if (message.payloadDataType == uint8(OrderlyCrossChainMessage.PayloadDataType.VaultTypesVaultWithdraw)) {
            VaultTypes.VaultWithdraw memory data = abi.decode(payload, (VaultTypes.VaultWithdraw));

            uint256 cvtTokenAmount = convertDecimal(data.tokenAmount, data.tokenHash, message.srcChainId, chainId);

            AccountTypes.AccountWithdraw memory withdrawData = AccountTypes.AccountWithdraw({
                accountId: data.accountId,
                sender: data.sender,
                receiver: data.receiver,
                brokerHash: data.brokerHash,
                tokenHash: data.tokenHash,
                tokenAmount: cvtTokenAmount,
                fee: data.fee,
                chainId: message.srcChainId,
                withdrawNonce: data.withdrawNonce
            });

            withdrawFinish(withdrawData);
        } else {
            revert("LedgerCrossChainManager: payloadDataType not match");
        }
    }

    function withdraw(EventTypes.WithdrawData calldata data) external override {
        // only ledger can call this function
        require(msg.sender == address(ledger), "caller is not ledger");

        OrderlyCrossChainMessage.MessageV1 memory message = OrderlyCrossChainMessage.MessageV1({
            method: uint8(OrderlyCrossChainMessage.CrossChainMethod.Withdraw),
            option: uint8(OrderlyCrossChainMessage.CrossChainOption.LayerZero),
            payloadDataType: uint8(OrderlyCrossChainMessage.PayloadDataType.EventTypesWithdrawData),
            srcCrossChainManager: address(this),
            dstCrossChainManager: vaultCrossChainManagers[data.chainId],
            srcChainId: chainId,
            dstChainId: data.chainId
        });

        // convert token amount to dst chain decimal
        uint256 cvtTokenAmount = convertDecimal(data.tokenAmount, data.tokenHash, chainId, data.chainId);
        data.tokenAmount = cvtTokenAmount;

        bytes memory payload = abi.encode(data);

        crossChainRelay.sendMessage(message, payload);
    }

    function withdrawFinish(AccountTypes.AccountWithdraw memory message) internal {
        ledger.accountWithDrawFinish(message);
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./interface/IVault.sol";
import "./interface/IVaultCrossChainManager.sol";
import "./library/Utils.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * Vault is responsible for saving user's USDC (where USDC which is a IERC20 token).
 * EACH CHAIN SHOULD HAVE ONE Vault CONTRACT.
 * User can deposit USDC from Vault.
 * Only crossChainManager can approve withdraw request.
 */
contract Vault is IVault, ReentrancyGuard, Ownable {
    // equal to `Utils.string2HashedBytes32('USDC')`
    // equal to `Utils.getTokenHash('USDC')`
    bytes32 constant USDC = bytes32(uint256(0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa));
    // cross-chain operator address
    address public crossChainManagerAddress;
    // tokenHash to token contract address mapping
    mapping(bytes32 => IERC20) public allowedTokenList;
    // list to record the hash value of allowed brokerIds
    mapping(bytes32 => bool) public allowedBrokerList;
    // deposit id / nonce
    uint64 public depositId;
    // CrossChainManager contract
    IVaultCrossChainManager public crossChainManager;

    // only cross-chain manager can call
    modifier onlyCrossChainManager() {
        if (msg.sender != crossChainManagerAddress) revert OnlyCrossChainManagerCanCall();
        _;
    }

    // change crossChainManager
    function setCrossChainManager(address _crossChainManagerAddress) public override onlyOwner {
        crossChainManagerAddress = _crossChainManagerAddress;
        crossChainManager = IVaultCrossChainManager(_crossChainManagerAddress);
    }

    // add contract address for an allowed token
    function addToken(bytes32 _tokenHash, address _tokenAddress) public override onlyOwner {
        allowedTokenList[_tokenHash] = IERC20(_tokenAddress);
    }

    // add the hash value for an allowed brokerId
    function addBroker(bytes32 _brokerHash) external override onlyOwner {
        allowedBrokerList[_brokerHash] = true;
    }

    // user deposit USDC
    function deposit(VaultTypes.VaultDepositFE calldata data) public override {
        IERC20 tokenAddress = allowedTokenList[data.tokenHash];
        // require tokenAddress exist
        if (address(tokenAddress) == address(0)) revert TokenNotAllowed();
        if (!allowedBrokerList[data.brokerHash]) revert BrokerNotAllowed();
        bool succ = tokenAddress.transferFrom(msg.sender, address(this), data.tokenAmount);
        if (!succ) revert TransferFromFailed();
        // cross-chain tx to ledger
        VaultTypes.VaultDeposit memory depositData = VaultTypes.VaultDeposit(
            data.accountId, msg.sender, data.brokerHash, data.tokenHash, data.tokenAmount, _newDepositId()
        );
        crossChainManager.deposit(depositData);
        // emit deposit event
        emit AccountDeposit(data.accountId, msg.sender, depositId, data.tokenHash, data.tokenAmount);
    }

    // user withdraw USDC
    function withdraw(VaultTypes.VaultWithdraw calldata data) public override onlyCrossChainManager nonReentrant {
        IERC20 tokenAddress = allowedTokenList[data.tokenHash];
        uint128 amount = data.tokenAmount - data.fee;
        // check balane gt amount
        if (tokenAddress.balanceOf(address(this)) < amount) {
            revert BalanceNotEnough(tokenAddress.balanceOf(address(this)), amount);
        }
        // transfer to user
        bool succ = tokenAddress.transfer(data.receiver, amount);
        if (!succ) revert TransferFailed();
        // send cross-chain tx to ledger
        crossChainManager.withdraw(data);
        // emit withdraw event
        emit AccountWithdraw(
            data.accountId,
            data.withdrawNonce,
            data.brokerHash,
            data.sender,
            data.receiver,
            data.tokenHash,
            data.tokenAmount,
            data.fee,
            block.timestamp
        );
    }

    function _newDepositId() internal returns (uint64) {
        depositId += 1;
        return depositId;
    }
}

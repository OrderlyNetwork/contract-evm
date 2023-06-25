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
    bytes32 constant USDC = bytes32(uint256(0x61fc29e9a6b4b52b423e75ca44734454f94ea60ddff3dc47af01a2a646fe9572));
    // cross-chain operator address
    address public crossChainManagerAddress;
    // symbol to token address mapping
    mapping(bytes32 => IERC20) public symbol2TokenAddress;
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

    // add token address
    function addTokenAddress(bytes32 _symbol, address _tokenAddress) public override onlyOwner {
        symbol2TokenAddress[_symbol] = IERC20(_tokenAddress);
    }

    // call `setCrossChainManager` later
    constructor(address _usdcAddress) {
        symbol2TokenAddress[USDC] = IERC20(_usdcAddress);
    }

    // user deposit USDC
    function deposit(VaultTypes.VaultDepositFE calldata data) public override {
        IERC20 tokenAddress = symbol2TokenAddress[data.tokenHash];
        // require tokenAddress exist
        if (address(tokenAddress) == address(0)) revert TokenNotExist();
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
        IERC20 tokenAddress = symbol2TokenAddress[data.tokenHash];
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

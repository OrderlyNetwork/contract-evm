// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./interface/IVault.sol";
import "./interface/IVaultCrossChainManager.sol";
import "./library/Utils.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts-upgradeable/contracts/security/PausableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * Vault is responsible for saving user's USDC (where USDC which is a IERC20 token).
 * EACH CHAIN SHOULD HAVE ONE Vault CONTRACT.
 * User can deposit USDC from Vault.
 * Only crossChainManager can approve withdraw request.
 */
contract Vault is IVault, PausableUpgradeable, OwnableUpgradeable {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using SafeERC20 for IERC20;

    // cross-chain operator address
    address public crossChainManagerAddress;
    mapping(bytes32 => bool) public _deprecatedA; // @Rubick depracated
    mapping(bytes32 => IERC20) public _deprecatedB; // @Rubick depracated

    // TODO @Rubick reorder to save slots
    // deposit id / nonce
    uint64 public depositId;
    // CrossChainManager contract
    IVaultCrossChainManager public _deprecated;

    // list to record the hash value of allowed brokerIds
    EnumerableSet.Bytes32Set private allowedBrokerSet;
    // tokenHash to token contract address mapping
    EnumerableSet.Bytes32Set private allowedTokenSet;
    mapping(bytes32 => address) public allowedToken;

    // only cross-chain manager can call
    modifier onlyCrossChainManager() {
        if (msg.sender != crossChainManagerAddress) revert OnlyCrossChainManagerCanCall();
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize() public override initializer {
        __Ownable_init();
        __Pausable_init();
    }

    // change crossChainManager
    function setCrossChainManager(address _crossChainManagerAddress) public override onlyOwner {
        crossChainManagerAddress = _crossChainManagerAddress;
    }

    // add contract address for an allowed token
    function setAllowedToken(bytes32 _tokenHash, bool _allowed) public override onlyOwner {
        if (_allowed) {
            allowedTokenSet.add(_tokenHash);
        } else {
            allowedTokenSet.remove(_tokenHash);
        }
    }

    // add the hash value for an allowed brokerId
    function setAllowedBroker(bytes32 _brokerHash, bool _allowed) public override onlyOwner {
        if (_allowed) {
            allowedBrokerSet.add(_brokerHash);
        } else {
            allowedBrokerSet.remove(_brokerHash);
        }
    }

    // change the token address for an allowed token
    function changeTokenAddressAndAllow(bytes32 _tokenHash, address _tokenAddress) public override onlyOwner {
        allowedToken[_tokenHash] = _tokenAddress;
        allowedTokenSet.add(_tokenHash);
    }

    // check if the tokenHash is allowed
    function getAllowedToken(bytes32 _tokenHash) public view override returns (address) {
        if (allowedTokenSet.contains(_tokenHash)) {
            return allowedToken[_tokenHash];
        } else {
            return address(0);
        }
    }

    // check if the brokerHash is allowed
    function getAllowedBroker(bytes32 _brokerHash) public view override returns (bool) {
        return allowedBrokerSet.contains(_brokerHash);
    }

    // get all allowed tokenHash
    function getAllAllowedToken() public view override returns (bytes32[] memory) {
        return allowedTokenSet.values();
    }

    // get all allowed brokerIds
    function getAllAllowedBroker() public view override returns (bytes32[] memory) {
        return allowedBrokerSet.values();
    }

    // user deposit
    function deposit(VaultTypes.VaultDepositFE calldata data) public override whenNotPaused {
        // require tokenAddress exist
        if (!allowedTokenSet.contains(data.tokenHash)) revert TokenNotAllowed();
        if (!allowedBrokerSet.contains(data.brokerHash)) revert BrokerNotAllowed();
        if (!Utils.validateAccountId(data.accountId, data.brokerHash, msg.sender)) revert AccountIdInvalid();
        IERC20 tokenAddress = IERC20(allowedToken[data.tokenHash]);
        // avoid non-standard ERC20 tranferFrom bug
        tokenAddress.safeTransferFrom(msg.sender, address(this), data.tokenAmount);
        // cross-chain tx to ledger
        VaultTypes.VaultDeposit memory depositData = VaultTypes.VaultDeposit(
            data.accountId, msg.sender, data.brokerHash, data.tokenHash, data.tokenAmount, _newDepositId()
        );
        IVaultCrossChainManager(crossChainManagerAddress).deposit(depositData);
        // emit deposit event
        emit AccountDeposit(data.accountId, msg.sender, depositId, data.tokenHash, data.tokenAmount);
    }

    // user withdraw
    function withdraw(VaultTypes.VaultWithdraw calldata data) public override onlyCrossChainManager whenNotPaused {
        IERC20 tokenAddress = IERC20(allowedToken[data.tokenHash]);
        uint128 amount = data.tokenAmount - data.fee;
        // check balane gt amount
        if (tokenAddress.balanceOf(address(this)) < amount) {
            revert BalanceNotEnough(tokenAddress.balanceOf(address(this)), amount);
        }
        // transfer to user
        // avoid non-standard ERC20 tranfer bug
        tokenAddress.safeTransfer(data.receiver, amount);
        // send cross-chain tx to ledger
        IVaultCrossChainManager(crossChainManagerAddress).withdraw(data);
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

    function emergencyPause() public onlyOwner {
        _pause();
    }

    function emergencyUnpause() public onlyOwner {
        _unpause();
    }
}

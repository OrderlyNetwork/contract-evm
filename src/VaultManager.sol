// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./interface/IVaultManager.sol";
import "./LedgerComponent.sol";

/**
 * VaultManager is responsible for saving vaults' balance, to ensure the cross-chain tx should success
 */
contract VaultManager is IVaultManager, LedgerComponent {
    // crossChainManagerAddress contract address
    address public crossChainManagerAddress;
    // valut balance, used for check if withdraw is valid
    mapping(bytes32 => mapping(uint256 => uint128)) private tokenBalanceOnchain;
    mapping(bytes32 => mapping(uint256 => bool)) private allowedToken; // supported token on each chain
    mapping(bytes32 => bool) private allowedBroker; // supported broker

    constructor() {
        _disableInitializers();
    }

    function initialize() public override initializer {
        __Ownable_init();
    }

    // get balance
    function getBalance(bytes32 _tokenHash, uint256 _chainId) public view override returns (uint128) {
        return tokenBalanceOnchain[_tokenHash][_chainId];
    }

    // add balance
    function addBalance(bytes32 _tokenHash, uint256 _chainId, uint128 _deltaBalance) public override onlyLedger {
        tokenBalanceOnchain[_tokenHash][_chainId] += _deltaBalance;
    }

    // sub balance
    function subBalance(bytes32 _tokenHash, uint256 _chainId, uint128 _deltaBalance) public override onlyLedger {
        tokenBalanceOnchain[_tokenHash][_chainId] -= _deltaBalance;
    }

    function setAllowedBroker(bytes32 _brokerHash, bool _allowed) public override onlyOwner {
        allowedBroker[_brokerHash] = _allowed;
    }

    function getAllowedBroker(bytes32 _brokerHash) public view override returns (bool) {
        return allowedBroker[_brokerHash];
    }

    function setAllowedToken(bytes32 _tokenHash, uint256 _chainId, bool _allowed) public override onlyOwner {
        allowedToken[_tokenHash][_chainId] = _allowed;
    }

    function getAllowedToken(bytes32 _tokenHash, uint256 _chainId) public view override returns (bool) {
        return allowedToken[_tokenHash][_chainId];
    }
}

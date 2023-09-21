// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./interface/IVaultManager.sol";
import "./LedgerComponent.sol";
import "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

/// @title Ledger call this manager for update vault data
/// @author Orderly_Rubick
/// @notice VaultManager is responsible for saving vaults' balance, to ensure the cross-chain tx should success
/// @notice VaultManager also saves the allowed brokerIds, tokenHash, symbolHash
contract VaultManager is IVaultManager, LedgerComponent {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    // A mapping to record how much balance each token has on each chain: tokenHash => chainId => balance
    mapping(bytes32 => mapping(uint256 => uint128)) private tokenBalanceOnchain;
    // A mapping to record how much balance each token has been frozen on each chain: tokenHash => chainId => frozenBalance
    mapping(bytes32 => mapping(uint256 => uint128)) private tokenFrozenBalanceOnchain;
    // A mapping to record which token has been allowed on each chain: tokenHash => chainId => allowed
    mapping(bytes32 => mapping(uint256 => bool)) private allowedChainToken; // supported token on each chain

    // A set to record supported tokenHash
    EnumerableSet.Bytes32Set private allowedTokenSet; // supported token
    // A set to record supported brokerHash
    EnumerableSet.Bytes32Set private allowedBrokerSet; // supported broker
    // A set to record supported symbolHash, this symbol means the trading pair, such BTC_USDC_PERP
    EnumerableSet.Bytes32Set private allowedSymbolSet; // supported symbol

    mapping(bytes32 => uint128) private maxWithdrawFee; // default = unlimited

    constructor() {
        _disableInitializers();
    }

    function initialize() external override initializer {
        __Ownable_init();
        setAllowedBroker(0x083098c593f395bea1de45dda552d9f14e8fcb0be3faaa7a1903c5477d7ba7fd, true); // woofi_dex
        setAllowedToken(0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa, true); // USDC
        setAllowedChainToken(0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa, 421613, true); // Arbitrum Goerli
        setAllowedSymbol(0xa2adc016e890b4fbbf161c7eaeb615b893e4fbeceae918fa7bf16cc40d46610b, true); // PERP_NEAR_USDC
        setAllowedSymbol(0x7e83089239db756ee233fa8972addfea16ae653db0f692e4851aed546b21caeb, true); // PERP_ETH_USDC
        setAllowedSymbol(0x5a8133e52befca724670dbf2cade550c522c2410dd5b1189df675e99388f509d, true); // PERP_BTC_USDC
        setAllowedSymbol(0x5d0471b083610a6f3b572fc8b0f759c5628e74159816681fb7d927b9263de60b, true); // PERP_WOO_USDC
    }

    /// @notice frozen & finish frozen
    function frozenBalance(bytes32 _tokenHash, uint256 _chainId, uint128 _deltaBalance) external override onlyLedger {
        tokenBalanceOnchain[_tokenHash][_chainId] -= _deltaBalance;
        tokenFrozenBalanceOnchain[_tokenHash][_chainId] += _deltaBalance;
    }

    function finishFrozenBalance(bytes32 _tokenHash, uint256 _chainId, uint128 _deltaBalance)
        external
        override
        onlyLedger
    {
        tokenFrozenBalanceOnchain[_tokenHash][_chainId] -= _deltaBalance;
    }

    /// @notice Get the token balance on the Vault contract given the tokenHash and chainId
    function getBalance(bytes32 _tokenHash, uint256 _chainId) public view override returns (uint128) {
        return tokenBalanceOnchain[_tokenHash][_chainId];
    }

    /// @notice Increase the token balance on the Vault contract given the tokenHash and chainId
    function addBalance(bytes32 _tokenHash, uint256 _chainId, uint128 _deltaBalance) external override onlyLedger {
        tokenBalanceOnchain[_tokenHash][_chainId] += _deltaBalance;
    }

    /// @notice Decrease the token balance on the Vault contract given the tokenHash and chainId
    function subBalance(bytes32 _tokenHash, uint256 _chainId, uint128 _deltaBalance) external override onlyLedger {
        tokenBalanceOnchain[_tokenHash][_chainId] -= _deltaBalance;
    }

    /// @notice Get the frozen token balance on the Vault contract given the tokenHash and chainId
    function getFrozenBalance(bytes32 _tokenHash, uint256 _chainId) public view override returns (uint128) {
        return tokenFrozenBalanceOnchain[_tokenHash][_chainId];
    }

    /// @notice Set the status for a broker given the brokerHash
    function setAllowedBroker(bytes32 _brokerHash, bool _allowed) public override onlyOwner {
        if (_allowed) {
            allowedBrokerSet.add(_brokerHash);
        } else {
            allowedBrokerSet.remove(_brokerHash);
        }
        emit SetAllowedBroker(_brokerHash, _allowed);
    }

    /// @notice Get the status for a broker given the brokerHash
    function getAllowedBroker(bytes32 _brokerHash) public view override returns (bool) {
        return allowedBrokerSet.contains(_brokerHash);
    }

    /// @notice Set the status for a token given the tokenHash and chainId
    function setAllowedChainToken(bytes32 _tokenHash, uint256 _chainId, bool _allowed) public override onlyOwner {
        allowedChainToken[_tokenHash][_chainId] = _allowed;
        emit SetAllowedChainToken(_tokenHash, _chainId, _allowed);
    }

    /// @notice Get the status for a token given the tokenHash and chainId
    function getAllowedChainToken(bytes32 _tokenHash, uint256 _chainId) public view override returns (bool) {
        return allowedTokenSet.contains(_tokenHash) && allowedChainToken[_tokenHash][_chainId];
    }

    /// @notice Set the status for a symbol given the symbolHash
    function setAllowedSymbol(bytes32 _symbolHash, bool _allowed) public override onlyOwner {
        if (_allowed) {
            allowedSymbolSet.add(_symbolHash);
        } else {
            allowedSymbolSet.remove(_symbolHash);
        }
        emit SetAllowedSymbol(_symbolHash, _allowed);
    }

    /// @notice Get the status for a symbol given the symbolHash
    function getAllowedSymbol(bytes32 _symbolHash) public view override returns (bool) {
        return allowedSymbolSet.contains(_symbolHash);
    }

    /// @notice Get all allowed tokenHash
    function getAllAllowedToken() public view override returns (bytes32[] memory) {
        return allowedTokenSet.values();
    }

    /// @notice Get all allowed brokerHash
    function getAllAllowedBroker() public view override returns (bytes32[] memory) {
        return allowedBrokerSet.values();
    }

    /// @notice Get all allowed symbolHash
    function getAllAllowedSymbol() public view override returns (bytes32[] memory) {
        return allowedSymbolSet.values();
    }

    /// @notice Set the status for a token given the tokenHash
    function setAllowedToken(bytes32 _tokenHash, bool _allowed) public override onlyOwner {
        if (_allowed) {
            allowedTokenSet.add(_tokenHash);
        } else {
            allowedTokenSet.remove(_tokenHash);
        }
        emit SetAllowedToken(_tokenHash, _allowed);
    }

    /// @notice Get the status for a token given the tokenHash
    function getAllowedToken(bytes32 _tokenHash) public view override returns (bool) {
        return allowedTokenSet.contains(_tokenHash);
    }

    /// @notice Set maxWithdrawFee
    function setMaxWithdrawFee(bytes32 _tokenHash, uint128 _maxWithdrawFee) public override onlyOwner {
        maxWithdrawFee[_tokenHash] = _maxWithdrawFee;
        emit SetMaxWithdrawFee(_tokenHash, _maxWithdrawFee);
    }

    /// @notice Get maxWithdrawFee
    function getMaxWithdrawFee(bytes32 _tokenHash) public view override returns (uint128) {
        return maxWithdrawFee[_tokenHash];
    }
}

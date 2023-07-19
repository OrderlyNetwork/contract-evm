// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../../src/interface/IVaultManager.sol";
import "../../src/LedgerComponent.sol";

contract VaultManagerBuggy is IVaultManager, LedgerComponent {
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

    function getBalance(bytes32 _tokenHash, uint256 _chainId) external view override returns (uint128) {}

    function addBalance(bytes32 _tokenHash, uint256 _chainId, uint128 _deltaBalance) external override {
        // should be add but sub
        tokenBalanceOnchain[_tokenHash][_chainId] -= _deltaBalance;
    }

    function subBalance(bytes32 _tokenHash, uint256 _chainId, uint128 _deltaBalance) external override {
        // should be sub but add
        tokenBalanceOnchain[_tokenHash][_chainId] += _deltaBalance;
    }

    function setAllowedBroker(bytes32 _brokerHash, bool _allowed) external override {}

    function getAllowedBroker(bytes32 _brokerHash) external view override returns (bool) {}

    function setAllowedChainToken(bytes32 _tokenHash, uint256 _chainId, bool _allowed) external override {}

    function getAllowedChainToken(bytes32 _tokenHash, uint256 _chainId) external view override returns (bool) {}

    function setAllowedSymbol(bytes32 _symbolHash, bool _allowed) external override {}

    function getAllowedSymbol(bytes32 _symbolHash) external view override returns (bool) {}

    function getAllAllowedToken() external view override returns (bytes32[] memory) {}

    function getAllAllowedBroker() external view override returns (bytes32[] memory) {}

    function getAllAllowedSymbol() external view override returns (bytes32[] memory) {}

    function setAllowedToken(bytes32 _tokenHash, bool _allowed) external override {}

    function getAllowedToken(bytes32 _tokenHash) external view override returns (bool) {}
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./interface/IVaultManager.sol";
import "./LedgerComponent.sol";

/**
 * VaultManager is responsible for saving vaults' balance, to ensure the cross-chain tx should success
 */
contract VaultManager is IVaultManager, LedgerComponent {
    // crossChainManagerAddress contract address
    address public crossChainManagerAddress;
    // valut balance, used for check if withdraw is valid
    mapping(uint256 => mapping(bytes32 => uint256)) chain2symbol2balance;

    // get balance
    function getBalance(uint256 _chainId, bytes32 _symbol) public view override returns (uint256) {
        return chain2symbol2balance[_chainId][_symbol];
    }

    // add balance
    function addBalance(uint256 _chainId, bytes32 _symbol, uint256 _deltaBalance) public override onlyLedger {
        chain2symbol2balance[_chainId][_symbol] += _deltaBalance;
    }

    // sub balance
    function subBalance(uint256 _chainId, bytes32 _symbol, uint256 _deltaBalance) public override onlyLedger {
        chain2symbol2balance[_chainId][_symbol] -= _deltaBalance;
    }
}

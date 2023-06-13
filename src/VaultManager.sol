// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./interface/IVaultManager.sol";

/**
 * VaultManager is responsible for saving vaults' balance, to ensure the cross-chain tx should success
 */
contract VaultManager is IVaultManager, Ownable {
    // crossChainManagerAddress contract address
    address public crossChainManagerAddress;
    // Ledger address
    address public ledgerAddress;
    // valut balance, used for check if withdraw is valid
    mapping(uint256 => mapping(bytes32 => uint256)) chain2symbol2balance;

    // only ledger
    modifier onlyLedger() {
        require(msg.sender == ledgerAddress, "only ledger can call");
        _;
    }

    // set ledgerAddress
    function setLedgerAddress(address _ledgerAddress) public onlyOwner {
        ledgerAddress = _ledgerAddress;
    }

    // get balance
    function getBalance(uint256 _chainId, bytes32 _symbol) public override view returns (uint256) {
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
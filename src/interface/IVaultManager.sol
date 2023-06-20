// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./ILedgerComponent.sol";

interface IVaultManager is ILedgerComponent {
    // get balance
    function getBalance(uint256 _chainId, bytes32 _symbol) external view returns (uint256);
    // add balance
    function addBalance(uint256 _chainId, bytes32 _symbol, uint256 _deltaBalance) external;
    // sub balance
    function subBalance(uint256 _chainId, bytes32 _symbol, uint256 _deltaBalance) external;
}

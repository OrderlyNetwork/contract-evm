// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./ILedgerComponent.sol";

interface IVaultManager is ILedgerComponent {
    // get balance
    function getBalance(bytes32 _tokenHash, uint256 _chainId) external view returns (uint128);
    // add balance
    function addBalance(bytes32 _tokenHash, uint256 _chainId, uint128 _deltaBalance) external;
    // sub balance
    function subBalance(bytes32 _tokenHash, uint256 _chainId, uint128 _deltaBalance) external;

    function setAllowedBroker(bytes32 _brokerHash, bool _allowed) external;
    function getAllowedBroker(bytes32 _brokerHash) external view returns (bool);

    function setAllowedToken(bytes32 _tokenHash, uint256 _chainId, bool _allowed) external;
    function getAllowedToken(bytes32 _tokenHash, uint256 _chainId) external view returns (bool);

}

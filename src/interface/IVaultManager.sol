// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./ILedgerComponent.sol";

interface IVaultManager is ILedgerComponent {
    function initialize() external;

    // get balance
    function getBalance(bytes32 _tokenHash, uint256 _chainId) external view returns (uint128);
    // add balance
    function addBalance(bytes32 _tokenHash, uint256 _chainId, uint128 _deltaBalance) external;
    // sub balance
    function subBalance(bytes32 _tokenHash, uint256 _chainId, uint128 _deltaBalance) external;

    // get frozen balance
    function getFrozenBalance(bytes32 _tokenHash, uint256 _chainId) external view returns (uint128);

    // frozen & finish frozen
    function frozenBalance(bytes32 _tokenHash, uint256 _chainId, uint128 _deltaBalance) external;
    function finishFrozenBalance(bytes32 _tokenHash, uint256 _chainId, uint128 _deltaBalance) external;

    // allow broker
    function setAllowedBroker(bytes32 _brokerHash, bool _allowed) external;
    function getAllowedBroker(bytes32 _brokerHash) external view returns (bool);

    // allow chain+token. in some chain, some token is not allowed for safety
    function setAllowedChainToken(bytes32 _tokenHash, uint256 _chainId, bool _allowed) external;
    function getAllowedChainToken(bytes32 _tokenHash, uint256 _chainId) external view returns (bool);

    // allow token
    function setAllowedToken(bytes32 _tokenHash, bool _allowed) external;
    function getAllowedToken(bytes32 _tokenHash) external view returns (bool);

    // allow symbol
    function setAllowedSymbol(bytes32 _symbolHash, bool _allowed) external;
    function getAllowedSymbol(bytes32 _symbolHash) external view returns (bool);

    // get allowed set
    function getAllAllowedToken() external view returns (bytes32[] memory);
    function getAllAllowedBroker() external view returns (bytes32[] memory);
    function getAllAllowedSymbol() external view returns (bytes32[] memory);
}

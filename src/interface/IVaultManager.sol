// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./ILedgerComponent.sol";
import "../library/types/RebalanceTypes.sol";
import "./error/IError.sol";

interface IVaultManager is IError, ILedgerComponent {
    function initialize() external;

    // event
    event SetAllowedBroker(bytes32 indexed _brokerHash, bool _allowed);
    event SetAllowedSymbol(bytes32 indexed _symbolHash, bool _allowed);
    event SetAllowedToken(bytes32 indexed _tokenHash, bool _allowed);
    event SetAllowedChainToken(bytes32 indexed _tokenHash, uint256 indexed _chainId, bool _allowed);
    event SetMaxWithdrawFee(bytes32 indexed _tokenHash, uint128 _maxWithdrawFee);

    // rebalance burn token
    event RebalanceBurn(
        uint64 indexed rebalanceId, uint128 amount, bytes32 tokenHash, uint256 srcChainId, uint256 dstChainId
    );
    // rebalance mint token
    event RebalanceMint(uint64 indexed rebalanceId);
    // rebalance burn result
    event RebalanceBurnResult(uint64 indexed rebalanceId, bool success);
    // rebalance mint result
    event RebalanceMintResult(uint64 indexed rebalanceId, bool success);

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
    function unfrozenBalance(bytes32 _tokenHash, uint256 _chainId, uint128 _deltaBalance) external;
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

    // maxWithdrawFee
    function setMaxWithdrawFee(bytes32 _tokenHash, uint128 _maxWithdrawFee) external;
    function getMaxWithdrawFee(bytes32 _tokenHash) external view returns (uint128);

    // chain2cctpDomain & chain2VaultAddress
    function setChain2cctpMeta(uint256 chainId, uint32 cctpDomain, address vaultAddress) external;

    // burn & mint with CCTP
    function executeRebalanceBurn(RebalanceTypes.RebalanceBurnUploadData calldata data)
        external
        returns (uint32, address);
    function rebalanceBurnFinish(RebalanceTypes.RebalanceBurnCCFinishData calldata data) external;
    function executeRebalanceMint(RebalanceTypes.RebalanceMintUploadData calldata data) external;
    function rebalanceMintFinish(RebalanceTypes.RebalanceMintCCFinishData calldata data) external;
    function getRebalanceStatus(uint64 rebalanceId) external view returns (RebalanceTypes.RebalanceStatus memory);
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./../library/types/VaultTypes.sol";
import "./../library/types/RebalanceTypes.sol";
import "./../library/types/EventTypes.sol";

interface IVault {
    error OnlyCrossChainManagerCanCall();
    error AccountIdInvalid();
    error TokenNotAllowed();
    error TokenNotDisabled();
    error DepositTokenDisabled();
    error InvalidTokenAddress();
    error BrokerNotAllowed();
    error BalanceNotEnough(uint256 balance, uint128 amount);
    error AddressZero();
    error EnumerableSetError();
    error ZeroDepositFee();
    error ZeroDeposit();
    error ZeroCodeLength();
    error NotZeroCodeLength();
    error DepositExceedLimit();
    error NativeTokenDepositAmountMismatch();
    error NotRebalanceEnableToken();
    error SwapAlreadySubmitted();
    error InvalidSwapSignature();
    error CeffuAddressMismatch(address want, address got);
    error SwapExpired(uint256 expirationTimestamp, uint256 currentTimestamp);

    // @deprecated
    event AccountDeposit(
        bytes32 indexed accountId,
        address indexed userAddress,
        uint64 indexed depositNonce,
        bytes32 tokenHash,
        uint128 tokenAmount
    );


    // deprecated
    event AccountDepositTo(
        bytes32 indexed accountId,
        address indexed userAddress,
        uint64 indexed depositNonce,
        bytes32 tokenHash,
        uint128 tokenAmount
    );

    event AccountDepositTo(
        bytes32 indexed accountId,
        bytes32 indexed brokerHash,
        address indexed userAddress,
        uint64  depositNonce,
        bytes32 tokenHash,
        uint128 tokenAmount
    );

    event AccountWithdraw(
        bytes32 indexed accountId,
        uint64 indexed withdrawNonce,
        bytes32 brokerHash,
        address sender,
        address receiver,
        bytes32 tokenHash,
        uint128 tokenAmount,
        uint128 fee
    );

    event AccountDelegate(
        address indexed delegateContract,
        bytes32 indexed brokerHash,
        address indexed delegateSigner,
        uint256 chainId,
        uint256 blockNumber
    );

    event SetAllowedToken(bytes32 indexed _tokenHash, bool _allowed);
    event SetAllowedBroker(bytes32 indexed _brokerHash, bool _allowed);
    event DisableDepositToken(bytes32 indexed _tokenHash);
    event EnableDepositToken(bytes32 indexed _tokenHash);
    event ChangeTokenAddressAndAllow(bytes32 indexed _tokenHash, address _tokenAddress);
    event ChangeCrossChainManager(address oldAddress, address newAddress);
    event ChangeDepositLimit(address indexed _tokenAddress, uint256 _limit);
    event WithdrawFailed(address indexed token, address indexed receiver, uint256 amount);
    event SetRebalanceEnableToken(bytes32 indexed _tokenHash, bool _allowed);
    event DelegateSwapExecuted(bytes32 indexed tradeId, bytes32 inTokenHash, uint256 inTokenAmount, address to, uint256 value);

    event SetProtocolVaultAddress(address _oldProtocolVaultAddress, address _newProtocolVaultAddress);
    event SetCeffuAddress(address _oldCeffuAddress, address _newCeffuAddress);

    event VaultAdapterSet(address adapter);

    // SetBroker from ledger events
    event SetBrokerFromLedgerAlreadySet(bytes32 indexed brokerHash, uint256 dstChainId, bool allowed);
    event SetBrokerFromLedgerSuccess(bytes32 indexed brokerHash, uint256 dstChainId, bool allowed);

    function initialize() external;

    function deposit(VaultTypes.VaultDepositFE calldata data) external payable;
    function depositTo(address receiver, VaultTypes.VaultDepositFE calldata data) external payable;
    function getDepositFee(address recevier, VaultTypes.VaultDepositFE calldata data) external view returns (uint256);
    function enableDepositFee(bool _enabled) external;
    function withdraw(VaultTypes.VaultWithdraw calldata data) external;
    function delegateSigner(VaultTypes.VaultDelegate calldata data) external;
    function withdraw2Contract(VaultTypes.VaultWithdraw2Contract calldata data) external;

    // CCTP: functions for receive rebalance msg
    function rebalanceMint(RebalanceTypes.RebalanceMintCCData calldata data) external;
    function rebalanceBurn(RebalanceTypes.RebalanceBurnCCData calldata data) external;
    function setTokenMessengerContract(address _tokenMessengerContract) external;
    function setRebalanceMessengerContract(address _rebalanceMessengerContract) external;

    // admin call
    function setCrossChainManager(address _crossChainManagerAddress) external;
    function setDepositLimit(address _tokenAddress, uint256 _limit) external;
    function setProtocolVaultAddress(address _protocolVaultAddress) external;
    function emergencyPause() external;
    function emergencyUnpause() external;

    // whitelist
    function setAllowedToken(bytes32 _tokenHash, bool _allowed) external;
    function disableDepositToken(bytes32 _tokenHash) external;
    function enableDepositToken(bytes32 _tokenHash) external;
    function setAllowedBroker(bytes32 _brokerHash, bool _allowed) external;
    function setNativeTokenHash(bytes32 _nativeTokenHash) external;
    function setNativeTokenDepositLimit(uint256 _nativeTokenDepositLimit) external;
    function setRebalanceEnableToken(bytes32 _tokenHash, bool _allowed) external;
    function changeTokenAddressAndAllow(bytes32 _tokenHash, address _tokenAddress) external;
    function getAllowedToken(bytes32 _tokenHash) external view returns (address);
    function getAllowedBroker(bytes32 _brokerHash) external view returns (bool);
    function getAllAllowedToken() external view returns (bytes32[] memory);
    function getAllAllowedBroker() external view returns (bytes32[] memory);
    function getAllRebalanceEnableToken() external view returns (bytes32[] memory);

    // cross-chain broker management
    function setBrokerFromLedger(EventTypes.SetBrokerData calldata data) external;

    // Delegate swap function
    function setSwapOperator(address _swapOperator) external;
    function setSwapSigner(address _swapSigner) external;
    function isSwapSubmitted(bytes32 tradeId) external view returns (bool);
    function delegateSwap(VaultTypes.DelegateSwap calldata data) external;
}

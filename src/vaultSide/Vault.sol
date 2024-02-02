// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../interface/IVault.sol";
import "../interface/IVaultCrossChainManager.sol";
import "../library/Utils.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts-upgradeable/contracts/security/PausableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interface/cctp/ITokenMessenger.sol";
import "../interface/cctp/IMessageTransmitter.sol";

/// @title Vault contract
/// @author Orderly_Rubick, Orderly_Zion
/// @notice Vault is responsible for saving user's erc20 token.
/// EACH CHAIN SHOULD HAVE ONE Vault CONTRACT.
/// User can deposit erc20 (USDC) from Vault.
/// Only crossChainManager can approve withdraw request.
contract Vault is IVault, PausableUpgradeable, OwnableUpgradeable {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using SafeERC20 for IERC20;

    // The cross-chain manager address on Vault side
    address public crossChainManagerAddress;
    // An incrasing deposit id / nonce on Vault side
    uint64 public depositId;

    // A set to record the hash value of all allowed brokerIds  // brokerHash = keccak256(abi.encodePacked(brokerId))
    EnumerableSet.Bytes32Set private allowedBrokerSet;
    // A set to record the hash value of all allowed tokens  // tokenHash = keccak256(abi.encodePacked(tokenSymbol))
    EnumerableSet.Bytes32Set private allowedTokenSet;
    // A mapping from tokenHash to token contract address
    mapping(bytes32 => address) public allowedToken;
    // A flag to indicate if deposit fee is enabled
    bool public depositFeeEnabled;

    // https://developers.circle.com/stablecoin/docs/cctp-protocol-contract#tokenmessenger-mainnet
    // TokenMessager for CCTP
    address public tokenMessengerContract;
    // MessageTransmitterContract for CCTP
    address public messageTransmitterContract;

    /// @notice Require only cross-chain manager can call
    modifier onlyCrossChainManager() {
        if (msg.sender != crossChainManagerAddress) revert OnlyCrossChainManagerCanCall();
        _;
    }

    /// @notice check non-zero address
    modifier nonZeroAddress(address _address) {
        if (_address == address(0)) revert AddressZero();
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize() external override initializer {
        __Ownable_init();
        __Pausable_init();
    }

    /// @notice Change crossChainManager address
    function setCrossChainManager(address _crossChainManagerAddress)
        public
        override
        onlyOwner
        nonZeroAddress(_crossChainManagerAddress)
    {
        emit ChangeCrossChainManager(crossChainManagerAddress, _crossChainManagerAddress);
        crossChainManagerAddress = _crossChainManagerAddress;
    }

    /// @notice Add contract address for an allowed token given the tokenHash
    /// @dev This function is only called when changing allow status for a token, not for initializing
    function setAllowedToken(bytes32 _tokenHash, bool _allowed) public override onlyOwner {
        bool succ = false;
        if (_allowed) {
            // require tokenAddress exist
            if (allowedToken[_tokenHash] == address(0)) revert AddressZero();
            succ = allowedTokenSet.add(_tokenHash);
        } else {
            succ = allowedTokenSet.remove(_tokenHash);
        }
        if (!succ) revert EnumerableSetError();
        emit SetAllowedToken(_tokenHash, _allowed);
    }

    /// @notice Add the hash value for an allowed brokerId
    function setAllowedBroker(bytes32 _brokerHash, bool _allowed) public override onlyOwner {
        bool succ = false;
        if (_allowed) {
            succ = allowedBrokerSet.add(_brokerHash);
        } else {
            succ = allowedBrokerSet.remove(_brokerHash);
        }
        if (!succ) revert EnumerableSetError();
        emit SetAllowedBroker(_brokerHash, _allowed);
    }

    /// @notice Change the token address for an allowed token, used when a new token is added
    /// @dev maybe should called `addTokenAddressAndAllow`, because it's for initializing
    function changeTokenAddressAndAllow(bytes32 _tokenHash, address _tokenAddress)
        public
        override
        onlyOwner
        nonZeroAddress(_tokenAddress)
    {
        allowedToken[_tokenHash] = _tokenAddress;
        allowedTokenSet.add(_tokenHash); // ignore returns here
        emit ChangeTokenAddressAndAllow(_tokenHash, _tokenAddress);
    }

    /// @notice Check if the given tokenHash is allowed on this Vault
    function getAllowedToken(bytes32 _tokenHash) public view override returns (address) {
        if (allowedTokenSet.contains(_tokenHash)) {
            return allowedToken[_tokenHash];
        } else {
            return address(0);
        }
    }

    /// @notice Check if the brokerHash is allowed on this Vault
    function getAllowedBroker(bytes32 _brokerHash) public view override returns (bool) {
        return allowedBrokerSet.contains(_brokerHash);
    }

    /// @notice Get all allowed tokenHash from this Vault
    function getAllAllowedToken() public view override returns (bytes32[] memory) {
        return allowedTokenSet.values();
    }

    /// @notice Get all allowed brokerIds hash from this Vault
    function getAllAllowedBroker() public view override returns (bytes32[] memory) {
        return allowedBrokerSet.values();
    }

    /// @notice The function to receive user deposit, VaultDepositFE type is defined in VaultTypes.sol
    function deposit(VaultTypes.VaultDepositFE calldata data) public payable override whenNotPaused {
        _deposit(msg.sender, data);
    }

    /// @notice The function to allow users to deposit on behalf of another user, the receiver is the user who will receive the deposit
    function depositTo(address receiver, VaultTypes.VaultDepositFE calldata data)
        public
        payable
        override
        whenNotPaused
    {
        _deposit(receiver, data);
    }

    /// @notice The function to query layerzero fee from CrossChainManager contract
    function getDepositFee(address receiver, VaultTypes.VaultDepositFE calldata data)
        public
        view
        override
        whenNotPaused
        returns (uint256)
    {
        _validateDeposit(receiver, data);
        VaultTypes.VaultDeposit memory depositData = VaultTypes.VaultDeposit(
            data.accountId, receiver, data.brokerHash, data.tokenHash, data.tokenAmount, depositId + 1
        );
        return (IVaultCrossChainManager(crossChainManagerAddress).getDepositFee(depositData));
    }

    /// @notice The function to enable/disable deposit fee
    function enableDepositFee(bool _enabled) public override onlyOwner whenNotPaused {
        depositFeeEnabled = _enabled;
    }

    /// @notice The function to call deposit of CCManager contract
    function _deposit(address receiver, VaultTypes.VaultDepositFE calldata data) internal whenNotPaused {
        _validateDeposit(receiver, data);
        // avoid reentrancy, so `transferFrom` token at the beginning
        IERC20 tokenAddress = IERC20(allowedToken[data.tokenHash]);
        // avoid non-standard ERC20 tranferFrom bug
        tokenAddress.safeTransferFrom(msg.sender, address(this), data.tokenAmount);
        // cross-chain tx to ledger
        VaultTypes.VaultDeposit memory depositData = VaultTypes.VaultDeposit(
            data.accountId, receiver, data.brokerHash, data.tokenHash, data.tokenAmount, _newDepositId()
        );
        // if deposit fee is enabled, user should pay fee in native token and the msg.value will be forwarded to CrossChainManager to pay for the layerzero cross-chain fee
        if (depositFeeEnabled) {
            if (msg.value == 0) revert ZeroDepositFee();
            IVaultCrossChainManager(crossChainManagerAddress).depositWithFee{value: msg.value}(depositData);
        } else {
            IVaultCrossChainManager(crossChainManagerAddress).deposit(depositData);
        }
        emit AccountDepositTo(data.accountId, receiver, depositId, data.tokenHash, data.tokenAmount);
    }

    /// @notice The function to validate deposit data
    function _validateDeposit(address receiver, VaultTypes.VaultDepositFE calldata data) internal view {
        // check if tokenHash and brokerHash are allowed
        if (!allowedTokenSet.contains(data.tokenHash)) revert TokenNotAllowed();
        if (!allowedBrokerSet.contains(data.brokerHash)) revert BrokerNotAllowed();
        // check if accountId = keccak256(abi.encodePacked(brokerHash, receiver))
        if (!Utils.validateAccountId(data.accountId, data.brokerHash, receiver)) revert AccountIdInvalid();
        // check if tokenAmount > 0
        if (data.tokenAmount == 0) revert ZeroDeposit();
    }

    /// @notice user withdraw
    function withdraw(VaultTypes.VaultWithdraw calldata data) public override onlyCrossChainManager whenNotPaused {
        // send cross-chain tx to ledger
        IVaultCrossChainManager(crossChainManagerAddress).withdraw(data);
        // avoid reentrancy, so `transfer` token at the end
        IERC20 tokenAddress = IERC20(allowedToken[data.tokenHash]);
        uint128 amount = data.tokenAmount - data.fee;
        // avoid revert if transfer to zero address.
        /// @notice This check condition should always be true because cc promise that
        if (data.receiver != address(0)) {
            // avoid non-standard ERC20 tranfer bug
            tokenAddress.safeTransfer(data.receiver, amount);
        }
        // emit withdraw event
        emit AccountWithdraw(
            data.accountId,
            data.withdrawNonce,
            data.brokerHash,
            data.sender,
            data.receiver,
            data.tokenHash,
            data.tokenAmount,
            data.fee
        );
    }

    function delegateSigner(VaultTypes.VaultDelegate calldata data) public override {
        if ((msg.sender).code.length == 0) revert ZeroCodeLength();
        if ((data.delegateSigner).code.length != 0) revert NotZeroCodeLength();
        if (!allowedBrokerSet.contains(data.brokerHash)) revert BrokerNotAllowed();

        // emit delegate event
        emit AccountDelegate(msg.sender, data.brokerHash, data.delegateSigner, block.chainid, block.number);
    }

    /// @notice Update the depositId
    function _newDepositId() internal returns (uint64) {
        return ++depositId;
    }

    function emergencyPause() public whenNotPaused onlyOwner {
        _pause();
    }

    function emergencyUnpause() public whenPaused onlyOwner {
        _unpause();
    }

    function setTokenMessengerContract(address _tokenMessengerContract)
        public
        override
        onlyOwner
        nonZeroAddress(_tokenMessengerContract)
    {
        tokenMessengerContract = _tokenMessengerContract;
    }

    function setRebalanceMessengerContract(address _rebalanceMessengerContract)
        public
        override
        onlyOwner
        nonZeroAddress(_rebalanceMessengerContract)
    {
        messageTransmitterContract = _rebalanceMessengerContract;
    }

    function rebalanceBurn(RebalanceTypes.RebalanceBurnCCData calldata data) external override onlyCrossChainManager {
        address burnToken = allowedToken[data.tokenHash];
        if (burnToken == address(0)) revert AddressZero();
        IERC20(burnToken).approve(tokenMessengerContract, data.amount);
        try ITokenMessenger(tokenMessengerContract).depositForBurn(
            data.amount, data.dstDomain, Utils.toBytes32(data.dstVaultAddress), burnToken
        ) {
            // send succ cross-chain tx to ledger
            // rebalanceId, amount, tokenHash, burnChainId, mintChainId | true
            IVaultCrossChainManager(crossChainManagerAddress).burnFinish(
                RebalanceTypes.RebalanceBurnCCFinishData({
                    rebalanceId: data.rebalanceId,
                    amount: data.amount,
                    tokenHash: data.tokenHash,
                    burnChainId: data.burnChainId,
                    mintChainId: data.mintChainId,
                    success: true
                })
            );
        } catch {
            // send fail cross-chain tx to ledger
            // rebalanceId, amount, tokenHash, burnChainId, mintChainId | false
            IVaultCrossChainManager(crossChainManagerAddress).burnFinish(
                RebalanceTypes.RebalanceBurnCCFinishData({
                    rebalanceId: data.rebalanceId,
                    amount: data.amount,
                    tokenHash: data.tokenHash,
                    burnChainId: data.burnChainId,
                    mintChainId: data.mintChainId,
                    success: false
                })
            );
        }
    }

    function rebalanceMint(RebalanceTypes.RebalanceMintCCData calldata data) external override onlyCrossChainManager {
        try IMessageTransmitter(messageTransmitterContract).receiveMessage(data.messageBytes, data.messageSignature) {
            // send succ cross-chain tx to ledger
            // rebalanceId, amount, tokenHash, burnChainId, mintChainId | true
            IVaultCrossChainManager(crossChainManagerAddress).mintFinish(
                RebalanceTypes.RebalanceMintCCFinishData({
                    rebalanceId: data.rebalanceId,
                    amount: data.amount,
                    tokenHash: data.tokenHash,
                    burnChainId: data.burnChainId,
                    mintChainId: data.mintChainId,
                    success: true
                })
            );
        } catch {
            // send fail cross-chain tx to ledger
            // rebalanceId, amount, tokenHash, burnChainId, mintChainId | false
            IVaultCrossChainManager(crossChainManagerAddress).mintFinish(
                RebalanceTypes.RebalanceMintCCFinishData({
                    rebalanceId: data.rebalanceId,
                    amount: data.amount,
                    tokenHash: data.tokenHash,
                    burnChainId: data.burnChainId,
                    mintChainId: data.mintChainId,
                    success: false
                })
            );
        }
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.26;

import "../interface/IVault.sol";
import "../interface/IVaultCrossChainManager.sol";
import "../library/Utils.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts-upgradeable/contracts/security/PausableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import "openzeppelin-contracts/contracts/utils/Address.sol";
import "../interface/cctpv2/ITokenMessengerV2.sol";
import "../interface/cctpv2/IMessageTransmitterV2.sol";
import "../interface/IProtocolVault.sol";
import "../library/DelegateSwapSignature.sol";
import "../oz5Revised/ReentrancyGuardRevised.sol";
import "../oz5Revised/AccessControlRevised.sol";
/// @title Vault contract
/// @author Orderly_Rubick, Orderly_Zion
/// @notice Vault is responsible for saving user's erc20 token.
/// EACH CHAIN SHOULD HAVE ONE Vault CONTRACT.
/// User can deposit erc20 (USDC) from Vault.
/// Only crossChainManager can approve withdraw request.

contract Vault is
    IVault,
    PausableUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardRevised,
    AccessControlRevised
{
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using SafeERC20 for IERC20;
    using Address for address payable;
    using SafeCast for uint256;
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

    // A set to record deposit limit for each token. 0 means unlimited
    mapping(address => uint256) public tokenAddress2DepositLimit;

    // Protocol Vault address
    IProtocolVault public protocolVault;

    // EnumerableSet for rebalance enable tokens
    EnumerableSet.Bytes32Set private _rebalanceEnableTokenSet;

    /*=============== Native Token ===============*/

    // Native token hash
    bytes32 public nativeTokenHash;

    // Native token deposit limit
    uint256 public nativeTokenDepositLimit;

    /*=============== Delegate  Swap ===============*/

    // Submitted Swap
    EnumerableSet.Bytes32Set private _submittedSwapSet;
    // Swap Operator Address
    address public swapOperator;
    // Swap Signer Address
    address public swapSigner;

    /*=============== CCTP Config ===============*/
    uint256 public cctpMaxFee;
    uint32 public cctpFinalityThreshold;

    // EnumerableSet for disabled deposit tokens
    // If a tokenHash is in this set, users cannot deposit this token, but user can still withdraw this token from Orderly
    EnumerableSet.Bytes32Set private disabledDepositTokenSet;
    // Vault Adapter Address
    address public vaultAdapter;

    // CCTP V2 model constants
    uint32 public constant CCTP_V2_FAST_MODEL = 1000;
    uint32 public constant CCTP_V2_NORMAL_MODEL = 2000;

    /* ================ Role ================ */

    bytes32 public constant SYMBOL_MANAGER_ROLE = keccak256("ORDERLY_MANAGER_SYMBOL_MANAGER_ROLE");

    bytes32 public constant BROKER_MANAGER_ROLE = keccak256("ORDERLY_MANAGER_BROKER_MANAGER_ROLE");

    /*=============== Modifiers ===============*/

    /// @notice onlyRoleOrOwner
    modifier onlyRoleOrOwner(bytes32 role) {
        if (!hasRole(role, msg.sender) && msg.sender != owner()) {
            revert AccessControlUnauthorizedAccount(msg.sender, role);
        }
        _;
    }

    /// @notice Require only swapOperator can call
    modifier onlySwapOperator() {
        require(msg.sender == swapOperator, "Vault: Only swap operator can call");
        _;
    }

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

    /// @notice Check if the token is supported and not disabled
    modifier checkDepositToken(bytes32 _tokenHash) {
        if (!allowedTokenSet.contains(_tokenHash)) revert TokenNotAllowed();
        if (disabledDepositTokenSet.contains(_tokenHash)) revert DepositTokenDisabled();
        // check the token address if the token is not native token
        if (_tokenHash != nativeTokenHash && allowedToken[_tokenHash] == address(0)) revert InvalidTokenAddress();
        _;
    }

    /*=============== Constructor ===============*/

    constructor() {
        _disableInitializers();
    }

    /*=============== Initializer ===============*/

    function initialize() external override initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
    }

    /*=============== Setters ===============*/

    /// @notice Sets broker status via cross-chain message from ledger
    /// @dev Only callable by the cross-chain manager, validates chain ID
    /// @param data The SetBrokerData containing broker information and status
    function setBrokerFromLedger(EventTypes.SetBrokerData calldata data) external override onlyCrossChainManager {
        // Chain ID validation (defense in depth) - using Solidity's built-in block.chainid
        require(data.dstChainId == block.chainid, "Vault: dstChainId mismatch");

        bool currentStatus = allowedBrokerSet.contains(data.brokerHash);

        if (data.allowed) {
            // Add broker operation
            if (currentStatus) {
                // Broker already exists, emit already set event
                emit SetBrokerFromLedgerAlreadySet(data.brokerHash, data.dstChainId, data.allowed);
                return;
            }
            // Add the broker using EnumerableSet
            allowedBrokerSet.add(data.brokerHash);
        } else {
            // Remove broker operation
            if (!currentStatus) {
                // Broker doesn't exist, emit already set event (broker already not present)
                emit SetBrokerFromLedgerAlreadySet(data.brokerHash, data.dstChainId, data.allowed);
                return;
            }
            // Remove the broker using EnumerableSet
            allowedBrokerSet.remove(data.brokerHash);
        }

        emit SetBrokerFromLedgerSuccess(data.brokerHash, data.dstChainId, data.allowed);
    }

    /// @notice Change crossChainManager address
    function setCrossChainManager(address _crossChainManagerAddress)
        external
        override
        onlyOwner
        nonZeroAddress(_crossChainManagerAddress)
    {
        emit ChangeCrossChainManager(crossChainManagerAddress, _crossChainManagerAddress);
        crossChainManagerAddress = _crossChainManagerAddress;
    }

    /// @notice Set deposit limit for a token
    function setDepositLimit(address _tokenAddress, uint256 _limit)
        external
        override
        onlyRoleOrOwner(SYMBOL_MANAGER_ROLE)
    {
        tokenAddress2DepositLimit[_tokenAddress] = _limit;
        emit ChangeDepositLimit(_tokenAddress, _limit);
    }

    /// @notice Set protocolVault address
    function setProtocolVaultAddress(address _protocolVaultAddress)
        external
        override
        onlyOwner
        nonZeroAddress(_protocolVaultAddress)
    {
        emit SetProtocolVaultAddress(address(protocolVault), _protocolVaultAddress);
        protocolVault = IProtocolVault(_protocolVaultAddress);
    }

    /// @notice Add contract address for an allowed token given the tokenHash
    /// @dev This function is only called when changing allow status for a token, not for initializing
    function setAllowedToken(bytes32 _tokenHash, bool _allowed) external override onlyOwner {
        bool succ = false;
        if (_allowed) {
            // require tokenAddress exist, except for native token
            if (allowedToken[_tokenHash] == address(0) && _tokenHash != nativeTokenHash) revert AddressZero();
            succ = allowedTokenSet.add(_tokenHash);
        } else {
            succ = allowedTokenSet.remove(_tokenHash);
            if (disabledDepositTokenSet.contains(_tokenHash)) {
                // if the token is already disabled, remove it
                disabledDepositTokenSet.remove(_tokenHash); 
            }
        }
        if (!succ) revert EnumerableSetError();
        emit SetAllowedToken(_tokenHash, _allowed);
    }

    function disableDepositToken(bytes32 _tokenHash) external override onlyRoleOrOwner(SYMBOL_MANAGER_ROLE) {
        if (!allowedTokenSet.contains(_tokenHash)) revert TokenNotAllowed();
        bool succ = disabledDepositTokenSet.add(_tokenHash);
        if (!succ) revert EnumerableSetError();
        emit DisableDepositToken(_tokenHash);
    }

    function enableDepositToken(bytes32 _tokenHash) external override onlyOwner {
        if (!disabledDepositTokenSet.contains(_tokenHash)) revert TokenNotDisabled();
        bool succ = disabledDepositTokenSet.remove(_tokenHash);
        if (!succ) revert EnumerableSetError();
        emit EnableDepositToken(_tokenHash);
    }

    function getDisabledDepositToken() external view returns (bytes32[] memory) {
        return disabledDepositTokenSet.values();
    }

    function setRebalanceEnableToken(bytes32 _tokenHash, bool _allowed) external override onlyOwner {
        bool succ = false;
        if (_allowed) {
            succ = _rebalanceEnableTokenSet.add(_tokenHash);
        } else {
            succ = _rebalanceEnableTokenSet.remove(_tokenHash);
        }
        if (!succ) revert EnumerableSetError();
        emit SetRebalanceEnableToken(_tokenHash, _allowed);
    }

    function getAllRebalanceEnableToken() external view returns (bytes32[] memory) {
        return _rebalanceEnableTokenSet.values();
    }

    /// @notice Add the hash value for an allowed brokerId
    function setAllowedBroker(bytes32 _brokerHash, bool _allowed)
        external
        override
        onlyRoleOrOwner(BROKER_MANAGER_ROLE)
    {
        bool succ = false;
        if (_allowed) {
            succ = allowedBrokerSet.add(_brokerHash);
        } else {
            succ = allowedBrokerSet.remove(_brokerHash);
        }
        if (!succ) revert EnumerableSetError();
        emit SetAllowedBroker(_brokerHash, _allowed);
    }

    /// @notice Set native token hash
    function setNativeTokenHash(bytes32 _nativeTokenHash) external override onlyOwner {
        nativeTokenHash = _nativeTokenHash;
    }

    /// @notice Set native token deposit limit
    function setNativeTokenDepositLimit(uint256 _nativeTokenDepositLimit)
        external
        override
        onlyRoleOrOwner(SYMBOL_MANAGER_ROLE)
    {
        nativeTokenDepositLimit = _nativeTokenDepositLimit;
    }

    /// @notice Change the token address for an allowed token, used when a new token is added
    /// @dev maybe should called `addTokenAddressAndAllow`, because it's for initializing
    function changeTokenAddressAndAllow(bytes32 _tokenHash, address _tokenAddress)
        external
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

    /*=============== Deposit ===============*/

    /// @notice The function to receive user deposit, VaultDepositFE type is defined in VaultTypes.sol
    function deposit(VaultTypes.VaultDepositFE calldata data) public payable override whenNotPaused {
        if (data.tokenHash == nativeTokenHash) {
            _ethDeposit(msg.sender, data);
        } else {
            _deposit(msg.sender, data);
        }
    }

    /// @notice The function to allow users to deposit on behalf of another user, the receiver is the user who will receive the deposit
    function depositTo(address receiver, VaultTypes.VaultDepositFE calldata data)
        public
        payable
        override
        whenNotPaused
    {
        if (data.tokenHash == nativeTokenHash) {
            _ethDeposit(receiver, data);
        } else {
            _deposit(receiver, data);
        }
    }

    /// @notice The function to query layerzero fee from CrossChainManager contract
    function getDepositFee(address receiver, VaultTypes.VaultDepositFE calldata data)
        public
        view
        override
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
    function _deposit(address receiver, VaultTypes.VaultDepositFE calldata data) internal {
        _validateDeposit(receiver, data);
        // avoid reentrancy, so `transferFrom` token at the beginning
        IERC20 tokenAddress = IERC20(allowedToken[data.tokenHash]);
        // check deposit limit
        /// @notice Be aware that we track the balance of the token in the contract, should be better track internal token deposit
        /// @notice Be aware that becuase of the async process of deposit & withdraw, the limit may be broken. So, it's a soft limit, not a hard limit
        if (
            tokenAddress2DepositLimit[address(tokenAddress)] != 0
                && data.tokenAmount + tokenAddress.balanceOf(address(this))
                    > tokenAddress2DepositLimit[address(tokenAddress)]
        ) {
            revert DepositExceedLimit();
        }
        // avoid non-standard ERC20 tranferFrom bug
        tokenAddress.safeTransferFrom(msg.sender, address(this), data.tokenAmount);
        // cross-chain tx to ledger
        VaultTypes.VaultDeposit memory depositData = VaultTypes.VaultDeposit(
            data.accountId, receiver, data.brokerHash, data.tokenHash, data.tokenAmount, _newDepositId()
        );
        // if deposit fee is enabled, user should pay fee in native token and the msg.value will be forwarded to CrossChainManager to pay for the layerzero cross-chain fee
        if (depositFeeEnabled) {
            if (msg.value == 0) revert ZeroDepositFee();
            IVaultCrossChainManager(crossChainManagerAddress).depositWithFeeRefund{value: msg.value}(
                msg.sender, depositData
            );
        } else {
            IVaultCrossChainManager(crossChainManagerAddress).deposit(depositData);
        }
        emit AccountDepositTo(data.accountId, data.brokerHash, receiver, depositId, data.tokenHash, data.tokenAmount);
    }

    function _ethDeposit(address receiver, VaultTypes.VaultDepositFE calldata data) internal {
        _validateDeposit(receiver, data);

        uint128 nativeDepositAmount = msg.value.toUint128();

        if (nativeDepositAmount < data.tokenAmount) revert NativeTokenDepositAmountMismatch();
        // check native token deposit limit
        if (
            nativeTokenDepositLimit != 0
                && (data.tokenAmount + address(this).balance - nativeDepositAmount) > nativeTokenDepositLimit
        ) {
            revert DepositExceedLimit();
        }
        // cross-chain tx to ledger
        VaultTypes.VaultDeposit memory depositData = VaultTypes.VaultDeposit(
            data.accountId, receiver, data.brokerHash, data.tokenHash, data.tokenAmount, _newDepositId()
        );

        // cross-chain fee
        uint256 crossChainFee = nativeDepositAmount - data.tokenAmount;

        // if deposit fee is enabled, user should pay fee in native token and the msg.value will be forwarded to CrossChainManager to pay for the layerzero cross-chain fee
        if (depositFeeEnabled) {
            if (crossChainFee == 0) revert ZeroDepositFee();
            IVaultCrossChainManager(crossChainManagerAddress).depositWithFeeRefund{value: crossChainFee}(
                msg.sender, depositData
            );
        } else {
            IVaultCrossChainManager(crossChainManagerAddress).deposit(depositData);
        }
        emit AccountDepositTo(data.accountId, data.brokerHash, receiver, depositId, data.tokenHash, data.tokenAmount);
    }

    /// @notice The function to validate deposit data
    function _validateDeposit(address receiver, VaultTypes.VaultDepositFE calldata data)
        internal
        view
        checkDepositToken(data.tokenHash)
    {
        // check if the brokerHash is allowed
        if (!allowedBrokerSet.contains(data.brokerHash)) revert BrokerNotAllowed();

        // check accountId validation based on caller
        if (msg.sender != vaultAdapter) {
            // Regular users can only use legacy account ID validation
            if (!Utils.validateAccountId(data.accountId, data.brokerHash, receiver)) {
                revert AccountIdInvalid();
            }
        }

        // check if tokenAmount > 0
        if (data.tokenAmount == 0) revert ZeroDeposit();
    }

    function _ethWithdraw(address receiver, uint128 amount) internal {
        payable(receiver).sendValue(amount);
    }

    /*=============== Withdraw ===============*/

    /// @notice user withdraw
    function withdraw(VaultTypes.VaultWithdraw calldata data) public override onlyCrossChainManager whenNotPaused {
        // send cross-chain tx to ledger
        IVaultCrossChainManager(crossChainManagerAddress).withdraw(data);

        require(data.tokenAmount > data.fee, "withdraw: fee is greater than token amount");

        uint128 amount = data.tokenAmount - data.fee;

        if (data.tokenHash == nativeTokenHash) {
            try this.attemptTransferNative(data.receiver, amount) {
                // do nothing
            } catch {
                // emit event to indicate withdraw fail, where zero address means native token
                emit WithdrawFailed(address(0), data.receiver, amount);
            }
        } else {
            // avoid reentrancy, so `transfer` token at the end
            IERC20 tokenAddress = IERC20(allowedToken[data.tokenHash]);
            require(tokenAddress.balanceOf(address(this)) >= amount, "withdraw: insufficient balance");
            // avoid revert if transfer to zero address or blacklist.
            /// @notice This check condition should always be true because cc promise that
            if (!_validReceiver(data.receiver, address(tokenAddress))) {
                emit WithdrawFailed(address(tokenAddress), data.receiver, amount);
            } else {
                tokenAddress.safeTransfer(data.receiver, amount);
            }
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

    /*=============== Withdraw2Contract ===============*/

    /// @notice withdraw to another contract by calling the contract's deposit function
    function withdraw2Contract(VaultTypes.VaultWithdraw2Contract calldata data)
        external
        onlyCrossChainManager
        whenNotPaused
    {
        VaultTypes.VaultWithdraw memory vaultWithdrawData = VaultTypes.VaultWithdraw({
            accountId: data.accountId,
            brokerHash: data.brokerHash,
            tokenHash: data.tokenHash,
            tokenAmount: data.tokenAmount,
            fee: data.fee,
            sender: data.sender,
            receiver: data.receiver,
            withdrawNonce: data.withdrawNonce
        });
        // send cross-chain tx to ledger
        IVaultCrossChainManager(crossChainManagerAddress).withdraw(vaultWithdrawData);

        require(data.tokenAmount > data.fee, "withdraw2Contract: fee is greater than token amount");

        uint128 amount = data.tokenAmount - data.fee;

        if (data.tokenHash == nativeTokenHash) {
            // _ethWithdraw(data.receiver, amount);
            try this.attemptTransferNative(data.receiver, amount) {
                // do nothing
            } catch {
                // emit event to indicate withdraw fail, where zero address means native token
                emit WithdrawFailed(address(0), data.receiver, amount);
            }
        } else {
            // avoid reentrancy, so `transfer` token at the end
            IERC20 tokenAddress = IERC20(allowedToken[data.tokenHash]);
            require(tokenAddress.balanceOf(address(this)) >= amount, "Vault: insufficient balance");
            // avoid revert if transfer to zero address or blacklist.
            /// @notice This check condition should always be true because cc promise that
            /// @notice But in some extreme cases (e.g. usdc contract pause) it will revert, devs should mannual fix it
            if (!_validReceiver(data.receiver, address(tokenAddress))) {
                emit WithdrawFailed(address(tokenAddress), data.receiver, amount);
            } else {
                // because we check type at the beginning, so we can safely check the type here
                if (data.vaultType == VaultTypes.VaultEnum.ProtocolVault) {
                    tokenAddress.safeApprove(data.receiver, amount);
                    IProtocolVault(data.receiver)
                        .depositFromStrategy(data.clientId, data.brokerHash, address(tokenAddress), amount);
                } else if (data.vaultType == VaultTypes.VaultEnum.Ceffu) {
                    tokenAddress.safeTransfer(data.receiver, amount);
                }
            }
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

    /// @notice validate if the receiver address is zero or in the blacklist
    function _validReceiver(address _receiver, address _token) internal view returns (bool) {
        if (_receiver == address(0)) {
            return false;
        } else if (_isBlacklisted(_receiver, _token)) {
            return false;
        } else {
            return true;
        }
    }

    /// @notice check if the receiver is in the blacklist in case the token contract has the blacklist function
    function _isBlacklisted(address _receiver, address _token) internal view returns (bool) {
        bytes memory data = abi.encodeWithSignature("isBlacklisted(address)", _receiver);
        (bool success, bytes memory result) = _token.staticcall(data);
        if (success) {
            return abi.decode(result, (bool));
        } else {
            return false;
        }
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

    function setCCTPConfig(uint256 _maxFee, uint32 _finalityThreshold) public onlyOwner {
        cctpMaxFee = _maxFee;
        require(
            _finalityThreshold == CCTP_V2_FAST_MODEL || _finalityThreshold == CCTP_V2_NORMAL_MODEL,
            "setCCTPConfig: invalid finality threshold"
        );
        cctpFinalityThreshold = _finalityThreshold;
    }

    function rebalanceBurn(RebalanceTypes.RebalanceBurnCCData calldata data) external override onlyCrossChainManager {
        /// Check if the token is allowed to be burned
        address burnToken = allowedToken[data.tokenHash];
        if (burnToken == address(0)) revert AddressZero();
        if (!_rebalanceEnableTokenSet.contains(data.tokenHash)) revert NotRebalanceEnableToken();

        /// Approve the token to be burned
        IERC20(burnToken).approve(tokenMessengerContract, data.amount);
        try ITokenMessengerV2(tokenMessengerContract)
            .depositForBurn(
                data.amount,
                data.dstDomain,
                Utils.toBytes32(data.dstVaultAddress),
                burnToken,
                Utils.toBytes32(data.dstVaultAddress),
                cctpMaxFee,
                cctpFinalityThreshold
            ) {
            // send succ cross-chain tx to ledger
            // rebalanceId, amount, tokenHash, burnChainId, mintChainId | true
            IVaultCrossChainManager(crossChainManagerAddress)
                .burnFinish(
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
            IVaultCrossChainManager(crossChainManagerAddress)
                .burnFinish(
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

        address mintToken = allowedToken[data.tokenHash];
        if (mintToken == address(0)) revert AddressZero();
        if (!_rebalanceEnableTokenSet.contains(data.tokenHash)) revert NotRebalanceEnableToken();

        uint256 balanceBeforeMint = IERC20(mintToken).balanceOf(address(this));
        try IMessageTransmitterV2(messageTransmitterContract).receiveMessage(data.messageBytes, data.messageSignature) {

            uint256 balanceAfterMint = IERC20(mintToken).balanceOf(address(this));
            uint256 mintedAmount = balanceAfterMint - balanceBeforeMint;

            // check the minted amount for normal finality model
            if (cctpFinalityThreshold == CCTP_V2_NORMAL_MODEL){
                require(mintedAmount == data.amount, "rebalanceMint: minted amount less than expected");
            }
            
            // send succ cross-chain tx to ledger
            // rebalanceId, amount, tokenHash, burnChainId, mintChainId | true
            IVaultCrossChainManager(crossChainManagerAddress).mintFinish(
                RebalanceTypes.RebalanceMintCCFinishData({
                    rebalanceId: data.rebalanceId,
                    amount: mintedAmount.toUint128(),
                    tokenHash: data.tokenHash,
                    burnChainId: data.burnChainId,
                    mintChainId: data.mintChainId,
                    success: true
                })
            );
        } catch Error(string memory reason) {
            // The method `receiveMessage` is permissionless, so it may fail due to others call it first
            // So if the reason is "Nonce already used", we treat it as success
            /// @notice This is still a bad practice, because maybe more errors will be treated as success (e.g. cctp contract pause & call it & unpause)
            /// But those corner cases are rare, and we can finally fix it
            string memory expectedReason = "Nonce already used";
            bool success = keccak256(abi.encodePacked(reason)) == keccak256(abi.encodePacked(expectedReason));
            IVaultCrossChainManager(crossChainManagerAddress)
                .mintFinish(
                    RebalanceTypes.RebalanceMintCCFinishData({
                        rebalanceId: data.rebalanceId,
                        amount: data.amount,
                        tokenHash: data.tokenHash,
                        burnChainId: data.burnChainId,
                        mintChainId: data.mintChainId,
                        success: success
                    })
                );
        }
    }

    // ============= Only THIS Function  ===============
    // add only this contract can call this function for try/catch use
    function attemptTransferNative(address _to, uint256 _amount) external {
        require(msg.sender == address(this), "Only this contract can call");
        payable(_to).sendValue(_amount);
    }

    /*=================================================
     =============== Delegate Swap ===============
     =================================================*/

    /// @notice Set the operator for the Swap
    function setSwapOperator(address _swapOperator) public override onlyOwner {
        swapOperator = _swapOperator;
    }

    /// @notice Set the signer for the Swap
    function setSwapSigner(address _swapSigner) public override onlyOwner {
        swapSigner = _swapSigner;
    }

    /// @notice Set the vault adapter address
    function setVaultAdapter(address _vaultAdapter) public onlyOwner nonZeroAddress(_vaultAdapter) {
        vaultAdapter = _vaultAdapter;

        emit VaultAdapterSet(vaultAdapter);
    }

    /// @notice Get all submitted swaps
    function getSubmittedSwaps() public view returns (bytes32[] memory) {
        return _submittedSwapSet.values();
    }

    /// @notice If submittedSwapSet contains the tradeId, return true
    function isSwapSubmitted(bytes32 tradeId) public view returns (bool) {
        return _submittedSwapSet.contains(tradeId);
    }

    function _verifySwapSignature(VaultTypes.DelegateSwap calldata data) internal view {
        // Verify Signature
        if (!DelegateSwapSignature.validateDelegateSwapSignature(swapSigner, data)) revert InvalidSwapSignature();
    }

    function _validateSwap(VaultTypes.DelegateSwap calldata data) internal view {
        // require nonce == swapNonce
        if (_submittedSwapSet.contains(data.tradeId)) revert SwapAlreadySubmitted();

        // Verify that the token is allowed
        bytes32 inTokenHash = data.inTokenHash;
        if (!allowedTokenSet.contains(inTokenHash)) revert TokenNotAllowed();

        // Verify that the owner has enough tokens
        if (inTokenHash != nativeTokenHash) {
            // ERC20 token case
            address tokenAddress = allowedToken[inTokenHash];
            if (tokenAddress == address(0)) revert InvalidTokenAddress();
        }

        // Verify Signature
        _verifySwapSignature(data);
    }

    /*=============== Delegate Swap ===============*/

    function delegateSwap(VaultTypes.DelegateSwap calldata data)
        external
        override
        whenNotPaused
        onlySwapOperator
        nonReentrant
    {
        _internalDelegateSwap(data);
    }

    /// @notice Delegate swap with expiration check
    function delegateSwapWithExpiration(VaultTypes.DelegateSwap calldata data, uint256 expirationTimestamp)
        external
        whenNotPaused
        onlySwapOperator
        nonReentrant
    {
        if (block.timestamp > expirationTimestamp) revert SwapExpired(expirationTimestamp, block.timestamp);
        _internalDelegateSwap(data);
    }

    function _internalDelegateSwap(VaultTypes.DelegateSwap calldata data) internal {
        _validateSwap(data);
        _submittedSwapSet.add(data.tradeId);

        if (data.inTokenHash != nativeTokenHash) {
            address tokenAddress = allowedToken[data.inTokenHash];
            IERC20 token = IERC20(tokenAddress);
            token.safeApprove(data.to, data.inTokenAmount);
        }

        uint256 value = 0;
        if (data.inTokenHash == nativeTokenHash) {
            value = data.value;
        }

        (bool success, bytes memory result) = data.to.call{value: value}(data.swapCalldata);
        if (!success) {
            assembly {
                revert(add(result, 0x20), mload(result))
            }
        }

        if (data.inTokenHash != nativeTokenHash) {
            address tokenAddress = allowedToken[data.inTokenHash];
            IERC20 token = IERC20(tokenAddress);
            token.safeApprove(data.to, 0);
        }

        emit DelegateSwapExecuted(data.tradeId, data.inTokenHash, data.inTokenAmount, data.to, data.value);
    }

    /* ================ Override AccessControlRevised To Simplify Access Control ================ */

    /// @notice Override grantRole
    function grantRole(bytes32 role, address account) public override onlyOwner {
        _grantRole(role, account);
    }

    /// @notice Override revokeRole
    function revokeRole(bytes32 role, address account) public override onlyOwner {
        _revokeRole(role, account);
    }
}

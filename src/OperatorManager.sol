// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "./dataLayout/OperatorManagerDataLayout.sol";
import "./interface/ILedger.sol";
import "./interface/IMarketManager.sol";
import "./interface/IOperatorManager.sol";
import "./interface/IOperatorManagerImplA.sol";
import "./library/Signature.sol";

/// @title Operator call this manager for update data
/// @author Orderly_Rubick
/// @notice OperatorManager is responsible for executing engine tx, only called by operator.
/// @notice This contract should only have one in main-chain
contract OperatorManager is IOperatorManager, OwnableUpgradeable, OperatorManagerDataLayout {
    // Using Storage as OZ 5.0 does
    struct OperatorManagerStorage {
        // Because of EIP170 size limit, the implementation should be split to impl contracts
        address operatorManagerImplA;
    }

    // keccak256(abi.encode(uint256(keccak256("orderly.OperatorManager")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OperatorManagerStorageLocation =
        0x345b139f871c60106e8079566993e0e04dc2ba53b7750d838960a732fe9c5100;

    function _getOperatorManagerStorage() private pure returns (OperatorManagerStorage storage $) {
        assembly {
            $.slot := OperatorManagerStorageLocation
        }
    }

    /// @notice Require only operator can call
    modifier onlyOperator() {
        // Update: operatorManagerZipAddress is also allowed to call
        if (msg.sender != operatorAddress && msg.sender != operatorManagerZipAddress) revert OnlyOperatorCanCall();
        _;
    }

    /// @notice check non-zero address
    modifier nonZeroAddress(address _address) {
        if (_address == address(0)) revert AddressZero();
        _;
    }

    /// @notice Set the operator address
    function setOperator(address _operatorAddress) external override onlyOwner nonZeroAddress(_operatorAddress) {
        emit ChangeOperator(1, operatorAddress, _operatorAddress);
        operatorAddress = _operatorAddress;
    }

    /// @notice Set engine signature address for spot trade upload
    function setEngineSpotTradeUploadAddress(address _engineSpotTradeUploadAddress)
        external
        override
        onlyOwner
        nonZeroAddress(_engineSpotTradeUploadAddress)
    {
        emit ChangeEngineUpload(1, engineSpotTradeUploadAddress, _engineSpotTradeUploadAddress);
        engineSpotTradeUploadAddress = _engineSpotTradeUploadAddress;
    }

    /// @notice Set engine signature address for perpetual future trade upload
    function setEnginePerpTradeUploadAddress(address _enginePerpTradeUploadAddress)
        external
        override
        onlyOwner
        nonZeroAddress(_enginePerpTradeUploadAddress)
    {
        emit ChangeEngineUpload(2, enginePerpTradeUploadAddress, _enginePerpTradeUploadAddress);
        enginePerpTradeUploadAddress = _enginePerpTradeUploadAddress;
    }

    /// @notice Set engine signature address for event upload
    function setEngineEventUploadAddress(address _engineEventUploadAddress)
        external
        override
        onlyOwner
        nonZeroAddress(_engineEventUploadAddress)
    {
        emit ChangeEngineUpload(3, engineEventUploadAddress, _engineEventUploadAddress);
        engineEventUploadAddress = _engineEventUploadAddress;
    }

    /// @notice Set engine signature address for market information upload
    function setEngineMarketUploadAddress(address _engineMarketUploadAddress)
        external
        override
        onlyOwner
        nonZeroAddress(_engineMarketUploadAddress)
    {
        emit ChangeEngineUpload(4, engineMarketUploadAddress, _engineMarketUploadAddress);
        engineMarketUploadAddress = _engineMarketUploadAddress;
    }

    /// @notice Set engine signature address for rebalance upload
    function setEngineRebalanceUploadAddress(address _engineRebalanceUploadAddress)
        external
        override
        onlyOwner
        nonZeroAddress(_engineRebalanceUploadAddress)
    {
        emit ChangeEngineUpload(5, engineRebalanceUploadAddress, _engineRebalanceUploadAddress);
        engineRebalanceUploadAddress = _engineRebalanceUploadAddress;
    }

    /// @notice Set the address of OperatorManagerZip contract
    function setOperatorManagerZipAddress(address _operatorManagerZipAddress)
        external
        override
        onlyOwner
        nonZeroAddress(_operatorManagerZipAddress)
    {
        emit ChangeOperator(2, operatorManagerZipAddress, _operatorManagerZipAddress);
        operatorManagerZipAddress = _operatorManagerZipAddress;
    }

    /// @notice Set the address of ledger contract
    function setLedger(address _ledger) external override onlyOwner nonZeroAddress(_ledger) {
        emit ChangeLedger(address(ledger), _ledger);
        ledger = ILedger(_ledger);
    }

    /// @notice Set the address of market manager contract
    function setMarketManager(address _marketManagerAddress)
        external
        override
        onlyOwner
        nonZeroAddress(_marketManagerAddress)
    {
        emit ChangeMarketManager(address(marketManager), _marketManagerAddress);
        marketManager = IMarketManager(_marketManagerAddress);
    }

    /// @notice Set the address of operator manager impl A contract
    function setOperatorManagerImplA(address _operatorManagerImplA)
        external
        override
        onlyOwner
        nonZeroAddress(_operatorManagerImplA)
    {
        _getOperatorManagerStorage().operatorManagerImplA = _operatorManagerImplA;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize() external override initializer {
        __Ownable_init();
        futuresUploadBatchId = 1;
        eventUploadBatchId = 1;
        lastOperatorInteraction = block.timestamp;
        // init all engine sign address
        // https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/315785217/Orderly+V2+Keys+Smart+Contract
    }

    /// @notice Operator ping to update last operator interaction timestamp
    function operatorPing() external onlyOperator {
        _delegatecall(abi.encodeWithSelector(IOperatorManagerImplA.operatorPing.selector));
    }

    /// @notice Function for perpetual futures trade upload
    function futuresTradeUpload(PerpTypes.FuturesTradeUploadData calldata data) external override onlyOperator {
        _delegatecall(abi.encodeWithSelector(IOperatorManagerImplA.futuresTradeUpload.selector, data));
    }

    /// @notice Function for event upload
    function eventUpload(EventTypes.EventUpload calldata data) external override onlyOperator {
        _delegatecall(abi.encodeWithSelector(IOperatorManagerImplA.eventUpload.selector, data));
    }

    /// @notice Function for perpetual futures price upload
    function perpPriceUpload(MarketTypes.UploadPerpPrice calldata data) external override onlyOperator {
        _delegatecall(abi.encodeWithSelector(IOperatorManagerImplA.perpPriceUpload.selector, data));
    }

    /// @notice Function for sum unitary fundings upload
    function sumUnitaryFundingsUpload(MarketTypes.UploadSumUnitaryFundings calldata data)
        external
        override
        onlyOperator
    {
        _delegatecall(abi.encodeWithSelector(IOperatorManagerImplA.sumUnitaryFundingsUpload.selector, data));
    }

    // @notice Function for rebalance burn upload
    function rebalanceBurnUpload(RebalanceTypes.RebalanceBurnUploadData calldata data) external override onlyOperator {
        _delegatecall(abi.encodeWithSelector(IOperatorManagerImplA.rebalanceBurnUpload.selector, data));
    }

    // @notice Function for rebalance mint upload
    function rebalanceMintUpload(RebalanceTypes.RebalanceMintUploadData calldata data) external override onlyOperator {
        _delegatecall(abi.encodeWithSelector(IOperatorManagerImplA.rebalanceMintUpload.selector, data));
    }

    /// @notice Function to check if the last operator interaction timestamp is over 3 days
    function checkEngineDown() external view override returns (bool) {
        return (lastOperatorInteraction + 3 days < block.timestamp);
    }

    // inner function for delegatecall
    function _delegatecall(bytes memory data) private {
        (bool success, bytes memory returnData) = _getOperatorManagerStorage().operatorManagerImplA.delegatecall(data);
        if (!success) {
            if (returnData.length > 0) {
                assembly {
                    revert(add(32, returnData), mload(returnData))
                }
            } else {
                revert DelegatecallFail();
            }
        }
    }
}

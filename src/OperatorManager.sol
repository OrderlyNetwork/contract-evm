// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "./dataLayout/OperatorManagerDataLayout.sol";
import "./interface/ILedger.sol";
import "./interface/IMarketManager.sol";
import "./interface/IOperatorManager.sol";
import "./library/Signature.sol";

/// @title Operator call this manager for update data
/// @author Orderly_Rubick
/// @notice OperatorManager is responsible for executing cefi tx, only called by operator.
/// @notice This contract should only have one in main-chain
contract OperatorManager is IOperatorManager, OwnableUpgradeable, OperatorManagerDataLayout {
    /// @notice Require only operator can call
    modifier onlyOperator() {
        if (msg.sender != operatorAddress) revert OnlyOperatorCanCall();
        _;
    }

    /// @notice Set the operator address
    function setOperator(address _operatorAddress) public override onlyOwner {
        if (_operatorAddress == address(0)) revert AddressZero();
        emit ChangeOperator(1, operatorAddress, _operatorAddress);
        operatorAddress = _operatorAddress;
    }

    /// @notice Set cefi signature address for spot trade upload
    function setCefiSpotTradeUploadAddress(address _cefiSpotTradeUploadAddress) public override onlyOwner {
        if (_cefiSpotTradeUploadAddress == address(0)) revert AddressZero();
        emit ChangeCefiUpload(1, cefiSpotTradeUploadAddress, _cefiSpotTradeUploadAddress);
        cefiSpotTradeUploadAddress = _cefiSpotTradeUploadAddress;
    }

    /// @notice Set cefi signature address for perpetual future trade upload
    function setCefiPerpTradeUploadAddress(address _cefiPerpTradeUploadAddress) public override onlyOwner {
        if (_cefiPerpTradeUploadAddress == address(0)) revert AddressZero();
        emit ChangeCefiUpload(2, cefiPerpTradeUploadAddress, _cefiPerpTradeUploadAddress);
        cefiPerpTradeUploadAddress = _cefiPerpTradeUploadAddress;
    }

    /// @notice Set cefi signature address for event upload
    function setCefiEventUploadAddress(address _cefiEventUploadAddress) public override onlyOwner {
        if (_cefiEventUploadAddress == address(0)) revert AddressZero();
        emit ChangeCefiUpload(3, cefiEventUploadAddress, _cefiEventUploadAddress);
        cefiEventUploadAddress = _cefiEventUploadAddress;
    }

    /// @notice Set cefi signature address for market information upload
    function setCefiMarketUploadAddress(address _cefiMarketUploadAddress) public override onlyOwner {
        if (_cefiMarketUploadAddress == address(0)) revert AddressZero();
        emit ChangeCefiUpload(4, cefiMarketUploadAddress, _cefiMarketUploadAddress);
        cefiMarketUploadAddress = _cefiMarketUploadAddress;
    }

    /// @notice Set the address of ledger contract
    function setLedger(address _ledger) public override onlyOwner {
        if (_ledger == address(0)) revert AddressZero();
        emit ChangeLedger(address(ledger), _ledger);
        ledger = ILedger(_ledger);
    }

    /// @notice Set the address of market manager contract
    function setMarketManager(address _marketManagerAddress) public override onlyOwner {
        if (_marketManagerAddress == address(0)) revert AddressZero();
        emit ChangeMarketManager(address(marketManager), _marketManagerAddress);
        marketManager = IMarketManager(_marketManagerAddress);
    }

    constructor() {
        _disableInitializers();
    }

    function initialize() external override initializer {
        __Ownable_init();
        futuresUploadBatchId = 1;
        eventUploadBatchId = 1;
        lastOperatorInteraction = block.timestamp;
        // init all cefi sign address
        // https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/315785217/Orderly+V2+Keys+Smart+Contract
        cefiSpotTradeUploadAddress = 0x4348C254D611fe55Ff1c58e7E20D33C14B0021A1;
        cefiPerpTradeUploadAddress = 0xd642D1b669b5021C057A81A917E1e831D97484AA;
        cefiEventUploadAddress = 0x1a4C6008d576E32b0B3D84E7620B4f4623c0cB38;
        cefiMarketUploadAddress = 0xE238F0A623D405b943B76700F85C56f0BE7d38da;
        operatorAddress = 0x056e1e2bF9F5C856A5D115e2B04742AE877098ac;
    }

    /// @notice Operator ping to update last operator interaction timestamp
    function operatorPing() public onlyOperator {
        _innerPing();
    }

    /// @notice Function for perpetual futures trade upload
    function futuresTradeUpload(PerpTypes.FuturesTradeUploadData calldata data) public override onlyOperator {
        if (data.batchId != futuresUploadBatchId) revert BatchIdNotMatch(data.batchId, futuresUploadBatchId);
        _innerPing();
        _futuresTradeUploadData(data);
        // emit event
        emit FuturesTradeUpload(data.batchId);
        // next wanted futuresUploadBatchId
        futuresUploadBatchId += 1;
    }

    /// @notice Function for event upload
    function eventUpload(EventTypes.EventUpload calldata data) public override onlyOperator {
        if (data.batchId != eventUploadBatchId) revert BatchIdNotMatch(data.batchId, eventUploadBatchId);
        _innerPing();
        _eventUploadData(data);
        // emit event
        emit EventUpload(data.batchId);
        // next wanted eventUploadBatchId
        eventUploadBatchId += 1;
    }

    /// @notice Function for perpetual futures price upload
    function perpPriceUpload(MarketTypes.UploadPerpPrice calldata data) public override onlyOperator {
        _innerPing();
        _perpMarketInfo(data);
    }

    /// @notice Function for sum unitary fundings upload
    function sumUnitaryFundingsUpload(MarketTypes.UploadSumUnitaryFundings calldata data)
        public
        override
        onlyOperator
    {
        _innerPing();
        _perpMarketInfo(data);
    }

    /// @notice Function to verify CeFi signature for futures trade upload data, if validated then Ledger contract will be called to execute the trade process
    function _futuresTradeUploadData(PerpTypes.FuturesTradeUploadData calldata data) internal {
        PerpTypes.FuturesTradeUpload[] calldata trades = data.trades;
        if (trades.length != data.count) revert CountNotMatch(trades.length, data.count);

        // check cefi signature
        bool succ = Signature.perpUploadEncodeHashVerify(data, cefiPerpTradeUploadAddress);
        if (!succ) revert SignatureNotMatch();

        // process each validated perp trades
        for (uint256 i = 0; i < data.count; i++) {
            _processValidatedFutures(trades[i]);
        }
    }

    /// @notice Cross-Contract call to Ledger contract to process each validated perp future trades
    function _processValidatedFutures(PerpTypes.FuturesTradeUpload calldata trade) internal {
        ledger.executeProcessValidatedFutures(trade);
    }

    /// @notice Function to verify CeFi signature for event upload data, if validated then Ledger contract will be called to execute the event process
    function _eventUploadData(EventTypes.EventUpload calldata data) internal {
        EventTypes.EventUploadData[] calldata events = data.events; // gas saving
        if (events.length != data.count) revert CountNotMatch(events.length, data.count);

        // check cefi signature
        bool succ = Signature.eventsUploadEncodeHashVerify(data, cefiEventUploadAddress);
        if (!succ) revert SignatureNotMatch();

        // process each event upload
        for (uint256 i = 0; i < data.count; i++) {
            _processEventUpload(events[i]);
        }
    }

    /// @notice Cross-Contract call to Ledger contract to process each event upload according to the event type
    function _processEventUpload(EventTypes.EventUploadData calldata data) internal {
        uint8 bizType = data.bizType;
        if (bizType == 1) {
            // withdraw
            ledger.executeWithdrawAction(abi.decode(data.data, (EventTypes.WithdrawData)), data.eventId);
        } else if (bizType == 2) {
            // settlement
            ledger.executeSettlement(abi.decode(data.data, (EventTypes.Settlement)), data.eventId);
        } else if (bizType == 3) {
            // adl
            ledger.executeAdl(abi.decode(data.data, (EventTypes.Adl)), data.eventId);
        } else if (bizType == 4) {
            // liquidation
            ledger.executeLiquidation(abi.decode(data.data, (EventTypes.Liquidation)), data.eventId);
        } else {
            revert InvalidBizType(bizType);
        }
    }

    /// @notice Function to verify CeFi signature for perpetual future price data, if validated then MarketManager contract will be called to execute the market process
    function _perpMarketInfo(MarketTypes.UploadPerpPrice calldata data) internal {
        // check cefi signature
        bool succ = Signature.marketUploadEncodeHashVerify(data, cefiMarketUploadAddress);
        if (!succ) revert SignatureNotMatch();
        // process perp market info
        marketManager.updateMarketUpload(data);
    }

    /// @notice Function to verify CeFi signature for sum unitary fundings data, if validated then MarketManager contract will be called to execute the market process
    function _perpMarketInfo(MarketTypes.UploadSumUnitaryFundings calldata data) internal {
        // check cefi signature
        bool succ = Signature.marketUploadEncodeHashVerify(data, cefiMarketUploadAddress);
        if (!succ) revert SignatureNotMatch();
        // process perp market info
        marketManager.updateMarketUpload(data);
    }

    /// @notice Function to update last operator interaction timestamp
    function _innerPing() internal {
        lastOperatorInteraction = block.timestamp;
    }

    /// @notice Function to check if the last operator interaction timestamp is over 3 days
    function checkCefiDown() public view override returns (bool) {
        return (lastOperatorInteraction + 3 days < block.timestamp);
    }
}

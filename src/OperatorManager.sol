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
/// @notice OperatorManager is responsible for executing engine tx, only called by operator.
/// @notice This contract should only have one in main-chain
contract OperatorManager is IOperatorManager, OwnableUpgradeable, OperatorManagerDataLayout {
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
    function setOperator(address _operatorAddress) public override onlyOwner nonZeroAddress(_operatorAddress) {
        emit ChangeOperator(1, operatorAddress, _operatorAddress);
        operatorAddress = _operatorAddress;
    }

    /// @notice Set engine signature address for spot trade upload
    function setEngineSpotTradeUploadAddress(address _engineSpotTradeUploadAddress)
        public
        override
        onlyOwner
        nonZeroAddress(_engineSpotTradeUploadAddress)
    {
        emit ChangeEngineUpload(1, engineSpotTradeUploadAddress, _engineSpotTradeUploadAddress);
        engineSpotTradeUploadAddress = _engineSpotTradeUploadAddress;
    }

    /// @notice Set engine signature address for perpetual future trade upload
    function setEnginePerpTradeUploadAddress(address _enginePerpTradeUploadAddress)
        public
        override
        onlyOwner
        nonZeroAddress(_enginePerpTradeUploadAddress)
    {
        emit ChangeEngineUpload(2, enginePerpTradeUploadAddress, _enginePerpTradeUploadAddress);
        enginePerpTradeUploadAddress = _enginePerpTradeUploadAddress;
    }

    /// @notice Set engine signature address for event upload
    function setEngineEventUploadAddress(address _engineEventUploadAddress)
        public
        override
        onlyOwner
        nonZeroAddress(_engineEventUploadAddress)
    {
        emit ChangeEngineUpload(3, engineEventUploadAddress, _engineEventUploadAddress);
        engineEventUploadAddress = _engineEventUploadAddress;
    }

    /// @notice Set engine signature address for market information upload
    function setEngineMarketUploadAddress(address _engineMarketUploadAddress)
        public
        override
        onlyOwner
        nonZeroAddress(_engineMarketUploadAddress)
    {
        emit ChangeEngineUpload(4, engineMarketUploadAddress, _engineMarketUploadAddress);
        engineMarketUploadAddress = _engineMarketUploadAddress;
    }

    /// @notice Set engine signature address for rebalance upload
    function setEngineRebalanceUploadAddress(address _engineRebalanceUploadAddress)
        public
        override
        onlyOwner
        nonZeroAddress(_engineRebalanceUploadAddress)
    {
        emit ChangeEngineUpload(5, engineRebalanceUploadAddress, _engineRebalanceUploadAddress);
        engineRebalanceUploadAddress = _engineRebalanceUploadAddress;
    }

    /// @notice Set the address of OperatorManagerZip contract
    function setOperatorManagerZipAddress(address _operatorManagerZipAddress)
        public
        override
        onlyOwner
        nonZeroAddress(_operatorManagerZipAddress)
    {
        emit ChangeOperator(2, operatorManagerZipAddress, _operatorManagerZipAddress);
        operatorManagerZipAddress = _operatorManagerZipAddress;
    }

    /// @notice Set the address of ledger contract
    function setLedger(address _ledger) public override onlyOwner nonZeroAddress(_ledger) {
        emit ChangeLedger(address(ledger), _ledger);
        ledger = ILedger(_ledger);
    }

    /// @notice Set the address of market manager contract
    function setMarketManager(address _marketManagerAddress)
        public
        override
        onlyOwner
        nonZeroAddress(_marketManagerAddress)
    {
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
        // init all engine sign address
        // https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/315785217/Orderly+V2+Keys+Smart+Contract
        engineSpotTradeUploadAddress = 0x4348C254D611fe55Ff1c58e7E20D33C14B0021A1;
        enginePerpTradeUploadAddress = 0xd642D1b669b5021C057A81A917E1e831D97484AA;
        engineEventUploadAddress = 0x1a4C6008d576E32b0B3D84E7620B4f4623c0cB38;
        engineMarketUploadAddress = 0xE238F0A623D405b943B76700F85C56f0BE7d38da;
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

    // @notice Function for rebalance burn upload
    function rebalanceBurnUpload(RebalanceTypes.RebalanceBurnUploadData calldata data) public override onlyOperator {
        _innerPing();
        _rebalanceBurnUpload(data);
        // emit event
        emit RebalanceBurnUpload(data.rebalanceId);
    }

    // @notice Function for rebalance mint upload
    function rebalanceMintUpload(RebalanceTypes.RebalanceMintUploadData calldata data) public override onlyOperator {
        _innerPing();
        _rebalanceMintUpload(data);
        // emit event
        emit RebalanceMintUpload(data.rebalanceId);
    }

    /// @notice Function to verify Engine signature for futures trade upload data, if validated then Ledger contract will be called to execute the trade process
    function _futuresTradeUploadData(PerpTypes.FuturesTradeUploadData calldata data) internal {
        PerpTypes.FuturesTradeUpload[] calldata trades = data.trades;
        if (trades.length != data.count) revert CountNotMatch(trades.length, data.count);

        // check engine signature
        bool succ = Signature.perpUploadEncodeHashVerify(data, enginePerpTradeUploadAddress);
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

    /// @notice Function to verify Engine signature for event upload data, if validated then Ledger contract will be called to execute the event process
    function _eventUploadData(EventTypes.EventUpload calldata data) internal {
        EventTypes.EventUploadData[] calldata events = data.events; // gas saving
        if (events.length != data.count) revert CountNotMatch(events.length, data.count);

        // check engine signature
        bool succ = Signature.eventsUploadEncodeHashVerify(data, engineEventUploadAddress);
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
        } else if (bizType == 5) {
            // fee disuribution
            ledger.executeFeeDistribution(abi.decode(data.data, (EventTypes.FeeDistribution)), data.eventId);
        } else if (bizType == 6) {
            // delegate signer
            ledger.executeDelegateSigner(abi.decode(data.data, (EventTypes.DelegateSigner)), data.eventId);
        } else if (bizType == 7) {
            // delegate withdraw
            ledger.executeDelegateWithdrawAction(abi.decode(data.data, (EventTypes.WithdrawData)), data.eventId);
        } else {
            revert InvalidBizType(bizType);
        }
    }

    /// @notice Function to verify Engine signature for perpetual future price data, if validated then MarketManager contract will be called to execute the market process
    function _perpMarketInfo(MarketTypes.UploadPerpPrice calldata data) internal {
        // check engine signature
        bool succ = Signature.marketUploadEncodeHashVerify(data, engineMarketUploadAddress);
        if (!succ) revert SignatureNotMatch();
        // process perp market info
        marketManager.updateMarketUpload(data);
    }

    /// @notice Function to verify Engine signature for sum unitary fundings data, if validated then MarketManager contract will be called to execute the market process
    function _perpMarketInfo(MarketTypes.UploadSumUnitaryFundings calldata data) internal {
        // check engine signature
        bool succ = Signature.marketUploadEncodeHashVerify(data, engineMarketUploadAddress);
        if (!succ) revert SignatureNotMatch();
        // process perp market info
        marketManager.updateMarketUpload(data);
    }

    /// @notice Cross-Contract call to Ledger contract to process each validated rebalance burn
    function _rebalanceBurnUpload(RebalanceTypes.RebalanceBurnUploadData calldata data) internal {
        // check engine signature
        bool succ = Signature.rebalanceBurnUploadEncodeHashVerify(data, engineRebalanceUploadAddress);
        if (!succ) revert SignatureNotMatch();
        // process rebalance burn
        ledger.executeRebalanceBurn(data);
    }

    /// @notice Cross-Contract call to Ledger contract to process each validated rebalance mint
    function _rebalanceMintUpload(RebalanceTypes.RebalanceMintUploadData calldata data) internal {
        // check engine signature
        bool succ = Signature.rebalanceMintUploadEncodeHashVerify(data, engineRebalanceUploadAddress);
        if (!succ) revert SignatureNotMatch();
        // process rebalance mint
        ledger.executeRebalanceMint(data);
    }

    /// @notice Function to update last operator interaction timestamp
    function _innerPing() internal {
        lastOperatorInteraction = block.timestamp;
    }

    /// @notice Function to check if the last operator interaction timestamp is over 3 days
    function checkEngineDown() public view override returns (bool) {
        return (lastOperatorInteraction + 3 days < block.timestamp);
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types/AccountTypes.sol";
import "../library/types/PerpTypes.sol";
import "../library/types/EventTypes.sol";
import "../library/types/MarketTypes.sol";
import "../library/types/RebalanceTypes.sol";
import "./error/IError.sol";

// IOperatorManager is IError because OperatorManager call Ledger (and other Managers), and may revert Ledger's error at operator side.
// So, the operator can get the human-readable error message from IError.
interface IOperatorManager is IError {
    error InvalidBizType(uint8 bizType);
    error BatchIdNotMatch(uint64 batchId, uint64 futuresUploadBatchId);
    error CountNotMatch(uint256 length, uint256 count);
    error SignatureNotMatch();

    event FuturesTradeUpload(uint64 indexed batchId);
    event EventUpload(uint64 indexed batchId);
    event ChangeEngineUpload(uint8 indexed types, address oldAddress, address newAddress);
    event ChangeOperator(uint8 indexed types, address oldAddress, address newAddress);
    event ChangeMarketManager(address oldAddress, address newAddress);
    event ChangeLedger(address oldAddress, address newAddress);
    event RebalanceBurnUpload(uint64 indexed rebalanceId);
    event RebalanceMintUpload(uint64 indexed rebalanceId);

    // @depreacted
    // All events below are deprecated
    // Keep them for indexer backward compatibility
    event FuturesTradeUpload(uint64 indexed batchId, uint256 blocktime);
    event EventUpload(uint64 indexed batchId, uint256 blocktime);

    function initialize() external;

    // operator call futures trade upload
    function futuresTradeUpload(PerpTypes.FuturesTradeUploadData calldata data) external;
    // operator call event upload
    function eventUpload(EventTypes.EventUpload calldata data) external;
    // operator call perp market info
    function perpPriceUpload(MarketTypes.UploadPerpPrice calldata data) external;
    function sumUnitaryFundingsUpload(MarketTypes.UploadSumUnitaryFundings calldata data) external;
    // operator call rebalance mint
    function rebalanceBurnUpload(RebalanceTypes.RebalanceBurnUploadData calldata) external;
    function rebalanceMintUpload(RebalanceTypes.RebalanceMintUploadData calldata) external;
    // operator call ping
    function operatorPing() external;

    // check if engine down
    function checkEngineDown() external returns (bool);

    // admin call
    function setOperator(address _operatorAddress) external;
    function setLedger(address _ledger) external;
    function setMarketManager(address _marketManagerAddress) external;
    function setEngineSpotTradeUploadAddress(address _engineSpotTradeUploadAddress) external;
    function setEnginePerpTradeUploadAddress(address _enginePerpTradeUploadAddress) external;
    function setEngineEventUploadAddress(address _engineEventUploadAddress) external;
    function setEngineMarketUploadAddress(address _engineMarketUploadAddress) external;
    function setEngineRebalanceUploadAddress(address _engineRebalanceUploadAddress) external;
}

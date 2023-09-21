// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types/AccountTypes.sol";
import "../library/types/PerpTypes.sol";
import "../library/types/EventTypes.sol";
import "../library/types/MarketTypes.sol";
import "./ILedgerError.sol";

// IOperatorManager is ILedgerError because OperatorManager call Ledger, and may revert Ledger's error at operator side.
// So, the operator can get the human-readable error message from ILedgerError.
interface IOperatorManager is ILedgerError {
    error InvalidBizType(uint8 bizType);
    error BatchIdNotMatch(uint64 batchId, uint64 futuresUploadBatchId);
    error CountNotMatch(uint256 length, uint256 count);
    error SignatureNotMatch();

    event FuturesTradeUpload(uint64 indexed batchId, uint256 blocktime);
    event EventUpload(uint64 indexed batchId, uint256 blocktime);
    event ChangeCefiUpload(uint8 indexed types, address oldAddress, address newAddress);
    event ChangeOperator(uint8 indexed types, address oldAddress, address newAddress);
    event ChangeMarketManager(address oldAddress, address newAddress);
    event ChangeLedger(address oldAddress, address newAddress);

    function initialize() external;

    // operator call futures trade upload
    function futuresTradeUpload(PerpTypes.FuturesTradeUploadData calldata data) external;
    // operator call event upload
    function eventUpload(EventTypes.EventUpload calldata data) external;
    // operator call perp market info
    function perpPriceUpload(MarketTypes.UploadPerpPrice calldata data) external;
    function sumUnitaryFundingsUpload(MarketTypes.UploadSumUnitaryFundings calldata data) external;
    // operator call ping
    function operatorPing() external;

    // check if cefi down
    function checkCefiDown() external returns (bool);

    // admin call
    function setOperator(address _operatorAddress) external;
    function setLedger(address _ledger) external;
    function setMarketManager(address _marketManagerAddress) external;
    function setCefiSpotTradeUploadAddress(address _cefiSpotTradeUploadAddress) external;
    function setCefiPerpTradeUploadAddress(address _cefiPerpTradeUploadAddress) external;
    function setCefiEventUploadAddress(address _cefiEventUploadAddress) external;
    function setCefiMarketUploadAddress(address _cefiMarketUploadAddress) external;
}

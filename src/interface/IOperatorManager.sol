// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types/OperatorTypes.sol";
import "../library/types/AccountTypes.sol";
import "../library/types/PerpTypes.sol";
import "../library/types/EventTypes.sol";

interface IOperatorManager {
    event EventUpload(uint64 indexed batchId, uint256 blocktime);

    // @deprecated TODO @Rubick should be removed
    function operatorExecuteAction(OperatorTypes.OperatorActionData actionData, bytes calldata action) external;

    // operator call futures trade upload
    function futuresTradeUpload(PerpTypes.FuturesTradeUploadData calldata data) external;
    // operator call event upload
    function eventUpload(EventTypes.EventUpload calldata data) external;
    // operator call ping
    function operatorPing() external;

    // check if cefi down
    function checkCefiDown() external returns (bool);

    // admin call
    function setOperator(address _operator) external;
    function setLedger(address _ledger) external;
}

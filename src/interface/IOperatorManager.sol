// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types/OperatorTypes.sol";
import "../library/types/AccountTypes.sol";
import "../library/types/PerpTypes.sol";

interface IOperatorManager {
    // @deprecated TODO @Rubick should be removed
    function operatorExecuteAction(OperatorTypes.OperatorActionData actionData, bytes calldata action) external;

    // operator call account register
    function accountRegisterAction(AccountTypes.AccountRegister calldata data) external;
    // operator call futures trade upload
    function futuresTradeUploadDataAction(PerpTypes.FuturesTradeUploadData calldata data) external;
    // operator call event upload
    function eventUploadDataAction(PerpTypes.EventUpload calldata data) external;
    // operator call ping
    function operatorPing() external;

    // check if cefi down
    function checkCefiDown() external returns (bool);

    // admin call
    function setOperator(address _operator) external;
    function setSettlement(address _settlement) external;
}

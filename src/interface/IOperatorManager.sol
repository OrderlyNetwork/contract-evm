// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types/OperatorTypes.sol";
import "../library/types/AccountTypes.sol";
import "../library/types/PerpTypes.sol";

interface IOperatorManager {
    // @deprecated TODO should be removed
    function operatorExecuteAction(OperatorTypes.OperatorActionData actionData, bytes calldata action) external;

    // operator call account register
    function accountRegisterAction(AccountTypes.AccountRegister calldata data) external;
    // operator call futures trade upload
    function futuresTradeUploadDataAction(PerpTypes.FuturesTradeUploadData calldata data) external;
    // operator call event upload
    function eventUploadDataAction(PerpTypes.EventUpload calldata data) external;

    // check if cefi down
    function checkCefiDown() external returns (bool);
}

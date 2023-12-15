// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types/PerpTypes.sol";
import "../library/types/PerpTypesZip.sol";
import "./error/IError.sol";

interface IOperatorManagerZip is IError {
    event ChangeOperator(address oldAddress, address newAddress);
    event ChangeOperatorManager(address oldAddress, address newAddress);

    function initialize() external;
    // admin call
    function setOperator(address _operatorAddress) external;
    function setOpeartorManager(address _operatorManager) external;
    function setSymbol(bytes32 symbolHash, uint8 symbolId) external;
    // opeartor call
    function decodeFuturesTradeUploadData(bytes calldata data) external;
    // misc
    function initSymbolId2Hash() external;
    function placeholder(PerpTypesZip.FuturesTradeUploadDataZip calldata zip) external;
}

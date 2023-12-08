// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types/PerpTypes.sol";
import "../library/types/PerpTypesZip.sol";

// IOperatorManager is ILedgerError because OperatorManager call Ledger, and may revert Ledger's error at operator side.
// So, the operator can get the human-readable error message from ILedgerError.
interface IOperatorManagerZip {
    error OnlyOperatorCanCall();
    error AddressZero();

    event ChangeOperator(address oldAddress, address newAddress);
    event ChangeOperatorManager(address oldAddress, address newAddress);

    function initialize() external;
    // admin call
    function setOperator(address _operatorAddress) external;
    function setOpeartorManager(address _operatorManager) external;
    function decodeFuturesTradeUploadData(bytes calldata data) external;
    function setSymbol(bytes32 symbolHash, uint8 symbolId) external;
}

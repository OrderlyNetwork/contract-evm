// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types/OperatorTypes.sol";
import "../library/types/PerpTypes.sol";
import "crosschain/utils/OrderlyCrossChainMessage.sol";

interface ILedgerCrossChainManager {
    // cross chain call deposit | from vault to leger
    function deposit(
        OrderlyCrossChainMessage.MessageV1 memory message
    ) external;

    // cross chain withdraw approve | from leger to vault
    function withdraw(PerpTypes.WithdrawData calldata data) external;
    // cross chain withdraw finish | from vault to leger
    function withdrawFinish(OrderlyCrossChainMessage.MessageV1 memory message) external;

    // admin call
    function setLedger(address _ledger) external;
    function setOperatorManager(address _operatorManager) external;
    function setCrossChainRelay(address _crossChainRelay) external;
}

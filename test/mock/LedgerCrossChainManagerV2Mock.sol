// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../../src/interface/ILedgerCrossChainManagerV2.sol";
import "../mock/VaultCrossChainManagerMock.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "../../src/interface/ILedger.sol";
import "../../src/library/types/VaultTypes.sol";

contract LedgerCrossChainManagerV2Mock is ILedgerCrossChainManagerV2, Ownable {
    ILedger public ledger;
    

    function withdraw(EventTypes.WithdrawDataSol memory data) public {
        // do nothing
    }
    function withdraw2ContractV2(EventTypes.Withdraw2ContractV2 memory data) public {
        // do nothing
    }
    function setBrokerFromLedger(address brokerManager, bytes32 brokerHash, uint16 brokerIndex) public {
        // do nothing
    }
}

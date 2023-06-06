// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/OperatorManager.sol";
import "../src/Ledger.sol";
import "../src/LedgerCrossChainManager.sol";

contract OperatorManagerTest is Test {
    address constant operatorAddress = address(0x1234567890);
    ILedgerCrossChainManager ledgerCrossChainManager;
    IOperatorManager operatorManager;
    ILedger ledger;

    function setUp() public {
        ledgerCrossChainManager = new LedgerCrossChainManager();
        operatorManager = new OperatorManager();
        ledger = new Ledger(address(operatorManager), address(ledgerCrossChainManager));
        operatorManager.setOperator(operatorAddress);
        operatorManager.setLedger(address(ledger));
        ledgerCrossChainManager.setLedger(address(ledger));
        ledgerCrossChainManager.setOperatorManager(address(operatorManager));
    }

    function test_ping() public {
        vm.prank(operatorAddress);
        operatorManager.operatorPing();
    }

    function testFail_pingNotOperator() public {
        vm.prank(address(0x1));
        operatorManager.operatorPing();
    }

    // function test_register() public {
    //     vm.prank(operatorAddress);
    //     AccountTypes.AccountRegister memory accountRegister = AccountTypes.AccountRegister(
    //         bytes32(0x847928ac5e1d1e0867035b1fcff57798ce1652ef12664ee4c387463acc502e93),
    //         address(0xc764E58c95B5b702abBe775FE09dc8F653Ea9e1a),
    //         bytes32(0xfb08c0b22085b07c3787ca55e02cc585a966b0799bfef3d32fc335d7107cedef)
    //     );
    //     operatorManager.accountRegisterAction(accountRegister);
    //     assertEq(ledger.getUserLedgerBrokerId(accountRegister.accountId), accountRegister.brokerId);
    // }
}

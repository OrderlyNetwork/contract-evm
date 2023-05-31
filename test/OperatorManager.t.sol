// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/OperatorManager.sol";
import "../src/Settlement.sol";
import "../src/SettlementCrossChainManager.sol";

contract OperatorManagerTest is Test {
    address constant operatorAddress = address(0x1234567890);
    ISettlementCrossChainManager settlementCrossChainManager;
    IOperatorManager operatorManager;
    ISettlement settlement;

    function setUp() public {
        settlementCrossChainManager = new SettlementCrossChainManager();
        operatorManager = new OperatorManager();
        settlement = new Settlement(address(operatorManager), address(settlementCrossChainManager));
        operatorManager.setOperator(operatorAddress);
        operatorManager.setSettlement(address(settlement));
    }

    function test_ping() public {
        vm.prank(operatorAddress);
        operatorManager.operatorPing();
    }

    function testFail_pingNotOperator() public {
        vm.prank(address(0x1));
        operatorManager.operatorPing();
    }

    function test_register() public {
        vm.prank(operatorAddress);
        AccountTypes.AccountRegister memory accountRegister = AccountTypes.AccountRegister(
            bytes32(0x847928ac5e1d1e0867035b1fcff57798ce1652ef12664ee4c387463acc502e93),
            address(0xc764E58c95B5b702abBe775FE09dc8F653Ea9e1a),
            bytes32(0xfb08c0b22085b07c3787ca55e02cc585a966b0799bfef3d32fc335d7107cedef)
        );
        operatorManager.accountRegisterAction(accountRegister);
        assertEq(settlement.getUserLedgerBrokerId(accountRegister.accountId), accountRegister.brokerId);
    }
}

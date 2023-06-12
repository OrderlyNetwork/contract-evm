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
        ledger = new Ledger();

        ledger.setOperatorManagerAddress(address(operatorManager));
        ledger.setCrossChainManager(address(ledgerCrossChainManager));

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

    // function test_deposit() public {
    //     vm.prank(operatorAddress);
    //     AccountTypes.AccountDeposit memory depositData = AccountTypes.AccountDeposit(
    //         bytes32(0x847928ac5e1d1e0867035b1fcff57798ce1652ef12664ee4c387463acc502e93),
    //         bytes32(0xfb08c0b22085b07c3787ca55e02cc585a966b0799bfef3d32fc335d7107cedef),
    //         address(0xc764E58c95B5b702abBe775FE09dc8F653Ea9e1a),
    //         bytes32(0x61fc29e9a6b4b52b423e75ca44734454f94ea60ddff3dc47af01a2a646fe9572),
    //         uint256(0x1000000),
    //         uint256(0x123),
    //         uint256(0x1)
    //     );
    //     ledgerCrossChainManager.deposit(depositData);
    //     assertEq(ledger.getUserLedgerBrokerId(depositData.accountId), depositData.brokerId);
    // }
}

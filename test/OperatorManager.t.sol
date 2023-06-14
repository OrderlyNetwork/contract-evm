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

    function test_EIP712() public {
        // assume the contract of this is `0x90193C961A926261B756D1E5bb255e67ff9498A1`
        EventTypes.WithdrawData memory data = EventTypes.WithdrawData(
            0x1794513e2fc05828d3205892dbef3c91eb7ffd6df62e0360acadd55650c9b672,
            0x4FDDB51ADe1fa66952de254bE7E1a84EEB153331,
            0x4FDDB51ADe1fa66952de254bE7E1a84EEB153331,
            'woofi_dex',
            'USDC',
            1000000,
            0,
            986532,
            123,
            1686648201277,
            27,
            0x90b44cb1c50eaca38cdbb972180d5bd6a328825aa60dc8e25f1c2cb9f1abc4a8,
            0x5bb52b33ae0d9e1733c80da1163a33034ee433bf949e8c96beb940ece3ab5683
        );
        vm.chainId(986532);
        bool succ = VerifyEIP712.verifyWithdraw(data.sender, data);
        require(succ, "verify failed");
    }

    function testFail_EIP712() public {
        EventTypes.WithdrawData memory data = EventTypes.WithdrawData(
            0x1794513e2fc05828d3205892dbef3c91eb7ffd6df62e0360acadd55650c9b672,
            0x4FDDB51ADe1fa66952de254bE7E1a84EEB153331,
            0x4FDDB51ADe1fa66952de254bE7E1a84EEB153331,
            'woofi_dex!!!!!!',
            'USDC',
            1000000,
            0,
            986532,
            123,
            1686644066387,
            27,
            0x4ab8ce3184c3c1ebcea11e93a4a93c3a6b01896f298cc3bcb086150f2238ca77,
            0x540b934b704d15f567056b331fa63876ef388c0bcc6e31b3c8c98896ff6fb16d
        );
        vm.chainId(986532);
        bool succ = VerifyEIP712.verifyWithdraw(data.sender, data);
        require(succ, "verify failed");
    }
}

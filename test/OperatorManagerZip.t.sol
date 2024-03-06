// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../src/OperatorManager.sol";
import "../src/zip/OperatorManagerZip.sol";
import "forge-std/console.sol";

// https://www.rareskills.io/post/solidity-test-internal-function
contract OperatorManagerZipHarness is OperatorManagerZip {
    function calcNotionalExternal(int128 tradeQty, uint128 executedPrice) external pure returns (int128) {
        return super.calcNotional(tradeQty, executedPrice);
    }

    function decodeFuturesTradeUploadDataExternal(bytes calldata data)
        external
        view
        returns (PerpTypes.FuturesTradeUploadData memory)
    {
        return super._decodeFuturesTradeUploadData(data);
    }

    function decodeEventUploadDataExternal(bytes calldata data) external view returns (EventTypes.EventUpload memory) {
        return super._decodeEventUploadData(data);
    }
}

contract OperatorManagerZipTest is Test {
    ProxyAdmin admin;
    address constant operatorAddress = address(0xDdDd1555A17d3Dad86748B883d2C1ce633A7cd88);
    IOperatorManager operatorManager;
    TransparentUpgradeableProxy operatorManagerProxy;
    TransparentUpgradeableProxy operatorManagerZipProxy;
    OperatorManagerZipHarness operatorManagerZip;
    OperatorManagerZipHarness zipHarness; // impl

    function setUp() public {
        admin = new ProxyAdmin();

        IOperatorManager operatorManagerImpl = new OperatorManager();
        zipHarness = new OperatorManagerZipHarness();

        bytes memory initData = abi.encodeWithSignature("initialize()");

        operatorManagerProxy = new TransparentUpgradeableProxy(address(operatorManagerImpl), address(admin), initData);
        operatorManagerZipProxy = new TransparentUpgradeableProxy(address(zipHarness), address(admin), initData);

        operatorManager = IOperatorManager(address(operatorManagerProxy));
        operatorManagerZip = OperatorManagerZipHarness(address(operatorManagerZipProxy));

        operatorManagerZip.setOperator(operatorAddress);
        operatorManagerZip.setOpeartorManager(address(operatorManager));

        operatorManagerZip.initSymbolId2Hash();
        operatorManagerZip.setSymbol(0x8c90e2c264110a5fde49d0ba875399b44e62b1a9933d3b3eb38e3b6ad3e2fe7a, 16);
        operatorManagerZip.setSymbol(0x8ad309d62169a7e303b9d78f3ab9e5cf4d5959a4185119b76999b5a92bb35654, 17);
        operatorManagerZip.setSymbol(0xb2713b988b6d440ab0a0c6566fef4b9a5773106b9a19de37c48a6ace61191b63, 18);
        operatorManagerZip.setSymbol(0x25355c64867293a1901661e8df83f2113b911d95635a03d850ddeacf8ce9e005, 19);
        operatorManagerZip.setSymbol(0xdfd18eb52f3d358f52ac4907bce4528df9441c766175f7bde5368b80febce163, 20);
        operatorManagerZip.setSymbol(0x8259df892f57a371c14416b118dfb755e7585d70fa52d531f6177b9dec0b8556, 21);
        operatorManagerZip.setSymbol(0xf2a6a5cfd2b55dd4f921bc8f23867c01aad15d8e16de1dd08b3259e699419719, 22);
    }

    function test_notionalCalc1() public {
        int128 tradeQty = 26400000000;
        uint128 executedPrice = 234950000;
        assertEq(zipHarness.calcNotionalExternal(tradeQty, executedPrice), 620268000);
    }

    function test_notionalCalc2() public {
        int128 tradeQty = -26400000000;
        uint128 executedPrice = 234950000;
        assertEq(zipHarness.calcNotionalExternal(tradeQty, executedPrice), -620268000);
    }

    // https://testnet-explorer.orderly.org/tx/0x4b3549cdfc5bf2cbadc7a20f9ce2e2bc6f88e5b1d02072726890d543ac7afc2a?tab=logs
    function test_decodeFutureTradeUpload() public {
        bytes memory inputData =
            hex"602040e45f1151a7c4403512e7a7d10577c6da45d1793c7dfa9fddf3c902fc0e749b283b105e5579b53fed38e881db79cd419e134ef7372b18d1fcf3b58c1588767616aee000611b001c41425e006102001d40c0006102585e220761ade872c94f85e62f1b24a74eec792aaa3677b6201071fd05c1698e8900610f0019430fab6481006315d54b6000630b48e800174501076f655bf4006201db3b006817b748d0c92ba29a000067018de34018b758225d0761ade872c94f85e62f1b24a74eec792aaa3677b6201071fd05c1698e8900610fff5dfffffffffffffffffffffffffffffffffffffffffffffffffffff0549b7f006315d54b6000374501076f655bf4006201db3c006817b748d0c92ba29a001845018de34018b7";
        PerpTypes.FuturesTradeUploadData memory data =
            operatorManagerZip.decodeFuturesTradeUploadDataExternal(inputData);
        // check data meta
        assertEq(data.batchId, 16990);
        assertEq(data.count, 2);
        // check upload[0] data
        PerpTypes.FuturesTradeUpload memory trade0 = data.trades[0];
        assertEq(trade0.accountId, 0x58220761ade872c94f85e62f1b24a74eec792aaa3677b6201071fd05c1698e89);
        assertEq(trade0.symbolHash, 0xa2adc016e890b4fbbf161c7eaeb615b893e4fbeceae918fa7bf16cc40d46610b);
        assertEq(trade0.feeAssetHash, 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa);
        assertEq(trade0.tradeQty, 67300000000);
        assertEq(trade0.notional, 2465199000);
        assertEq(trade0.executedPrice, 366300000);
        assertEq(trade0.fee, 739560);
        assertEq(trade0.sumUnitaryFundings, 289650000000000);
        assertEq(trade0.tradeId, 121659);
        assertEq(trade0.matchId, 1708914645175870106);
        assertEq(trade0.timestamp, 1708914645175);
        assertFalse(trade0.side);
        // check upload[1] data
        PerpTypes.FuturesTradeUpload memory trade1 = data.trades[1];
        assertEq(trade1.accountId, 0x58220761ade872c94f85e62f1b24a74eec792aaa3677b6201071fd05c1698e89);
        assertEq(trade1.symbolHash, 0xa2adc016e890b4fbbf161c7eaeb615b893e4fbeceae918fa7bf16cc40d46610b);
        assertEq(trade1.feeAssetHash, 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa);
        assertEq(trade1.tradeQty, -67300000000);
        assertEq(trade1.notional, -2465199000);
        assertEq(trade1.executedPrice, 366300000);
        assertEq(trade1.fee, 0);
        assertEq(trade1.sumUnitaryFundings, 289650000000000);
        assertEq(trade1.tradeId, 121660);
        assertEq(trade1.matchId, 1708914645175870106);
        assertEq(trade1.timestamp, 1708914645175);
        assertTrue(trade1.side);
    }

    // https://testnet-explorer.orderly.org/tx/0x09afa6c24357d1c8d615c73f9f587f9f79160cd725cbe2eb405b4147e6b50ae5?tab=logs
    function test_decodeEventUploadData_settlement() public {
        bytes memory inputData =
            hex"60201e41c0745f9c53bf36cd417b3f3bb0627a8e235577f69c53ce4b21fa8e85236410e86e94485e1d7d7d0239d986819bf176f49c2b0750727fa26b28ba56c5e21637f180131d00611c001d40010062070d001d4001006120001d400200630f4ded001d406000620120001d41202d5f7f165afa581711dec503b332511d3e9691068e03bd66cca63dadcc5a26e91fd65eaca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa003f3845018de324db880061e0001e";
        EventTypes.EventUpload memory data = operatorManagerZip.decodeEventUploadDataExternal(inputData);
        // check data meta
        assertEq(data.batchId, 1805);
        // check upload[0] data
        EventTypes.EventUploadData memory event0 = data.events[0];
        assertEq(event0.bizType, 2);
        assertEq(event0.eventId, 1002989);
        EventTypes.Settlement memory settlement = abi.decode(event0.data, (EventTypes.Settlement));
        assertEq(settlement.accountId, 0x2d7f165afa581711dec503b332511d3e9691068e03bd66cca63dadcc5a26e91f);
        assertEq(settlement.settledAssetHash, 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa);
        assertEq(settlement.insuranceAccountId, 0x0000000000000000000000000000000000000000000000000000000000000000);
        assertEq(settlement.settledAmount, 0);
        assertEq(settlement.insuranceTransferAmount, 0);
        assertEq(settlement.settlementExecutions.length, 0);
    }
}

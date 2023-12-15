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
}

contract OperatorManagerZipTest is Test {
    ProxyAdmin admin;
    address constant operatorAddress = address(0xDdDd1555A17d3Dad86748B883d2C1ce633A7cd88);
    IOperatorManager operatorManager;
    IOperatorManagerZip operatorManagerZip;
    TransparentUpgradeableProxy operatorManagerProxy;
    TransparentUpgradeableProxy operatorManagerZipProxy;
    OperatorManagerZipHarness zipHarness;

    function setUp() public {
        admin = new ProxyAdmin();

        IOperatorManager operatorManagerImpl = new OperatorManager();
        IOperatorManagerZip operatorManagerZipImpl = new OperatorManagerZip();

        bytes memory initData = abi.encodeWithSignature("initialize()");

        operatorManagerProxy = new TransparentUpgradeableProxy(address(operatorManagerImpl), address(admin), initData);
        operatorManagerZipProxy =
            new TransparentUpgradeableProxy(address(operatorManagerZipImpl), address(admin), initData);

        operatorManager = IOperatorManager(address(operatorManagerProxy));
        operatorManagerZip = IOperatorManagerZip(address(operatorManagerZipProxy));

        operatorManagerZip.setOperator(operatorAddress);
        operatorManagerZip.setOpeartorManager(address(operatorManager));

        zipHarness = new OperatorManagerZipHarness();
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
}

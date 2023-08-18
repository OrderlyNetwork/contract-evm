// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../src/FeeManager.sol";
import "../src/Ledger.sol";

contract FeeManagerTest is Test {
    ProxyAdmin admin;
    IFeeManager feeManager;
    ILedger ledger;
    TransparentUpgradeableProxy feeManagerProxy;
    TransparentUpgradeableProxy ledgerManagerProxy;
    bytes32 constant accountId1 = 0x6b97733ca568eddf2559232fa831f8de390a76d4f29a2962c3a9d0020383f7e3;
    bytes32 constant accountId2 = 0x6b97733ca568eddf2559232fa831f8de390a76d4f29a2962c3a9d0020383f7e4;
    bytes32 constant accountId3 = 0x6b97733ca568eddf2559232fa831f8de390a76d4f29a2962c3a9d0020383f7e5;

    function setUp() public {
        admin = new ProxyAdmin();

        IFeeManager feeManagerImpl = new FeeManager();
        ILedger ledgerImpl = new Ledger();

        feeManagerProxy = new TransparentUpgradeableProxy(address(feeManagerImpl), address(admin), "");
        ledgerManagerProxy = new TransparentUpgradeableProxy(address(ledgerImpl), address(admin), "");

        feeManager = IFeeManager(address(feeManagerProxy));
        ledger = ILedger(address(ledgerManagerProxy));

        feeManager.initialize();
        ledger.initialize();

        feeManager.setLedgerAddress(address(ledger));
        ledger.setFeeManager(address(feeManager));
    }

    function test_set_get() public {
        feeManager.changeFeeCollector(IFeeManager.FeeCollectorType.WithdrawFeeCollector, accountId2);
        assertEq(feeManager.getFeeCollector(IFeeManager.FeeCollectorType.WithdrawFeeCollector), accountId2);
        feeManager.changeFeeCollector(IFeeManager.FeeCollectorType.FuturesFeeCollector, accountId3);
        assertEq(feeManager.getFeeCollector(IFeeManager.FeeCollectorType.FuturesFeeCollector), accountId3);
    }
}

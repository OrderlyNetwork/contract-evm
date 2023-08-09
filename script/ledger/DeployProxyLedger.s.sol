// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/OperatorManager.sol";
import "../../src/Ledger.sol";
import "../../src/VaultManager.sol";
import "../../src/FeeManager.sol";
import "../../src/MarketManager.sol";

contract DeployLedger is Script {
    bytes32 constant BROKER_HASH = 0x083098c593f395bea1de45dda552d9f14e8fcb0be3faaa7a1903c5477d7ba7fd; // woofi_dex
    bytes32 constant TOKEN_HASH = 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa; // USDC
    uint256 constant CHAIN_ID = 43113; // fuji

    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");

        vm.startBroadcast(orderlyPrivateKey);

        ProxyAdmin admin = new ProxyAdmin();

        IOperatorManager operatorManagerImpl = new OperatorManager();
        IVaultManager vaultManagerImpl = new VaultManager();
        ILedger ledgerImpl = new Ledger();
        IFeeManager feeImpl = new FeeManager();
        IMarketManager marketImpl = new MarketManager();

        TransparentUpgradeableProxy operatorProxy =
            new TransparentUpgradeableProxy(address(operatorManagerImpl), address(admin), "");
        TransparentUpgradeableProxy vaultProxy =
            new TransparentUpgradeableProxy(address(vaultManagerImpl), address(admin), "");
        TransparentUpgradeableProxy ledgerProxy =
            new TransparentUpgradeableProxy(address(ledgerImpl), address(admin), "");
        TransparentUpgradeableProxy feeProxy = new TransparentUpgradeableProxy(address(feeImpl), address(admin), "");
        TransparentUpgradeableProxy marketProxy =
            new TransparentUpgradeableProxy(address(marketImpl), address(admin), "");

        IOperatorManager operatorManager = IOperatorManager(address(operatorProxy));
        IVaultManager vaultManager = IVaultManager(address(vaultProxy));
        ILedger ledger = ILedger(address(ledgerProxy));
        IFeeManager feeManager = IFeeManager(address(feeProxy));
        IMarketManager marketManager = IMarketManager(address(marketProxy));

        operatorManager.initialize();
        vaultManager.initialize();
        ledger.initialize();
        feeManager.initialize();
        marketManager.initialize();

        // avoid stack too deep error
        {
            address operatorAdminAddress = vm.envAddress("OPERATOR_ADMIN_ADDRESS");
            address ledgerCrossChainManagerAddress = vm.envAddress("LEDGER_CROSS_CHAIN_MANAGER_ADDRESS");
            ILedgerCrossChainManager ledgerCrossChainManager = ILedgerCrossChainManager(ledgerCrossChainManagerAddress);

            ledger.setOperatorManagerAddress(address(operatorManager));
            ledger.setCrossChainManager(address(ledgerCrossChainManager));
            ledger.setVaultManager(address(vaultManager));
            ledger.setFeeManager(address(feeManager));
            ledger.setMarketManager(address(marketManager));

            operatorManager.setOperator(operatorAdminAddress);
            operatorManager.setLedger(address(ledger));

            vaultManager.setLedgerAddress(address(ledger));
            vaultManager.setAllowedBroker(BROKER_HASH, true);
            vaultManager.setAllowedToken(TOKEN_HASH, true);
            vaultManager.setAllowedChainToken(TOKEN_HASH, CHAIN_ID, true);
            // vaultManager.setAllowedSymbol(SYMBOL_HASH, true);

            feeManager.setLedgerAddress(address(ledger));
            // feeManager.changeFeeCollector(1, address(0x1));
            // feeManager.changeFeeCollector(2, address(0x2));
            // feeManager.changeFeeCollector(3, address(0x3));

            marketManager.setOperatorManagerAddress(address(operatorManager));
            marketManager.setLedgerAddress(address(ledger));

            ledgerCrossChainManager.setLedger(address(ledger));
        }
        vm.stopBroadcast();
    }
}

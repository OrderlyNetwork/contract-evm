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
import "../utils/BaseScript.s.sol";
import "../utils/ConfigHelper.s.sol";

contract DeployLedger is BaseScript, ConfigHelper {
    string env;
    string network;

    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        Envs memory envs = getEnvs();
        env = envs.env;
        network = envs.ledgerNetwork;

        vm.startBroadcast(orderlyPrivateKey);

        ProxyAdmin admin = new ProxyAdmin();

        // avoid stack too deep error
        {
            console.log("deployed proxyAdmin address: ", address(admin));
            writeLedgerDeployData(env, network, "proxyAdmin", vm.toString(address(admin)));
        }

        IOperatorManager operatorManagerImpl = new OperatorManager();
        IVaultManager vaultManagerImpl = new VaultManager();
        ILedger ledgerImpl = new Ledger();
        IFeeManager feeImpl = new FeeManager();
        IMarketManager marketImpl = new MarketManager();

        bytes memory initData = abi.encodeWithSignature("initialize()");

        TransparentUpgradeableProxy operatorProxy =
            new TransparentUpgradeableProxy(address(operatorManagerImpl), address(admin), initData);
        TransparentUpgradeableProxy vaultProxy =
            new TransparentUpgradeableProxy(address(vaultManagerImpl), address(admin), initData);
        TransparentUpgradeableProxy ledgerProxy =
            new TransparentUpgradeableProxy(address(ledgerImpl), address(admin), initData);
        TransparentUpgradeableProxy feeProxy =
            new TransparentUpgradeableProxy(address(feeImpl), address(admin), initData);
        TransparentUpgradeableProxy marketProxy =
            new TransparentUpgradeableProxy(address(marketImpl), address(admin), initData);

        // avoid stack too deep error
        {
            console.log("deployed operatorManager proxy address: ", address(operatorProxy));
            console.log("deployed vaultManager proxy address: ", address(vaultProxy));
            console.log("deployed ledger proxy address: ", address(ledgerProxy));
            console.log("deployed feeManager proxy address: ", address(feeProxy));
            console.log("deployed marketManager proxy address: ", address(marketProxy));
            writeLedgerDeployData(env, network, "operatorManager", vm.toString(address(operatorProxy)));
            writeLedgerDeployData(env, network, "vaultManager", vm.toString(address(vaultProxy)));
            writeLedgerDeployData(env, network, "ledger", vm.toString(address(ledgerProxy)));
            writeLedgerDeployData(env, network, "feeManager", vm.toString(address(feeProxy)));
            writeLedgerDeployData(env, network, "marketManager", vm.toString(address(marketProxy)));

            console.log("deployed success");
        }

        IOperatorManager operatorManager = IOperatorManager(address(operatorProxy));
        IVaultManager vaultManager = IVaultManager(address(vaultProxy));
        ILedger ledger = ILedger(address(ledgerProxy));
        IFeeManager feeManager = IFeeManager(address(feeProxy));
        IMarketManager marketManager = IMarketManager(address(marketProxy));

        // avoid stack too deep error
        {
            LedgerDeployData memory config = getLedgerDeployData(env, network);
            address operatorAdminAddress = config.operatorAddress;
            console.log("operatorAdminAddress: ", operatorAdminAddress);

            ledger.setOperatorManagerAddress(address(operatorManager));
            ledger.setVaultManager(address(vaultManager));
            ledger.setFeeManager(address(feeManager));
            ledger.setMarketManager(address(marketManager));

            operatorManager.setOperator(operatorAdminAddress);
            operatorManager.setLedger(address(ledger));
            operatorManager.setMarketManager(address(marketManager));

            vaultManager.setLedgerAddress(address(ledger));

            feeManager.setLedgerAddress(address(ledger));

            marketManager.setOperatorManagerAddress(address(operatorManager));
            marketManager.setLedgerAddress(address(ledger));
        }
        vm.stopBroadcast();

        console.log("All done!");
    }
}

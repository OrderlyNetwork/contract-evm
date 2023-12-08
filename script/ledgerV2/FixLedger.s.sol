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

contract FixLedger is BaseScript, ConfigHelper {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        Envs memory envs = getEnvs();
        string memory env = envs.env;
        string memory network = envs.ledgerNetwork;

        LedgerDeployData memory config = getLedgerDeployData(env, network);
        address ledgerAddress = config.ledger;
        address operatorManagerAddress = config.operatorManager;
        address vaultManagerAddresss = config.vaultManager;
        address feeManagerAddress = config.feeManager;
        address marketManagerAddress = config.marketManager;
        address operatorAdminAddress = config.operatorAddress;
        console.log("ledgerAddress: ", ledgerAddress);
        console.log("operatorManagerAddress: ", operatorManagerAddress);
        console.log("vaultManagerAddresss: ", vaultManagerAddresss);
        console.log("feeManagerAddress: ", feeManagerAddress);
        console.log("marketManagerAddress: ", marketManagerAddress);
        console.log("operatorAdminAddress: ", operatorAdminAddress);

        vm.startBroadcast(orderlyPrivateKey);

        IOperatorManager operatorManager = IOperatorManager(address(operatorManagerAddress));
        ILedger ledger = ILedger(address(ledgerAddress));
        IVaultManager vaultManager = IVaultManager(address(vaultManagerAddresss));
        IFeeManager feeManager = IFeeManager(address(feeManagerAddress));
        IMarketManager marketManager = IMarketManager(address(marketManagerAddress));

        // avoid stack too deep error
        {
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

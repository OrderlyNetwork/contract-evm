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

contract TransferOwner is BaseScript, ConfigHelper {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        Envs memory envs = getEnvs();
        string memory env = envs.env;
        string memory network = envs.ledgerNetwork;

        LedgerDepolyData memory config = getLedgerDeployData(env, network);
        address adminAddress = config.proxyAdmin;
        address feeManagerAddress = config.feeManager;
        address marketManagerAddress = config.marketManager;
        address operatorManagerAddress = config.operatorManager;
        address vaultManagerAddress = config.vaultManager;
        address ledgerAddress = config.ledger;
        address multiSigAddress = config.multiSig;
        console.log("adminAddress: ", adminAddress);
        console.log("feeManagerAddress: ", feeManagerAddress);
        console.log("marketManagerAddress: ", marketManagerAddress);
        console.log("operatorManagerAddress: ", operatorManagerAddress);
        console.log("vaultManagerAddress: ", vaultManagerAddress);
        console.log("ledgerAddress: ", ledgerAddress);
        console.log("multiSigAddress: ", multiSigAddress);

        vm.startBroadcast(orderlyPrivateKey);

        {
            // first change the owner of the impls
            OperatorManager operatorManager = OperatorManager(operatorManagerAddress);
            VaultManager vaultManager = VaultManager(vaultManagerAddress);
            Ledger ledger = Ledger(ledgerAddress);
            FeeManager feeManager = FeeManager(feeManagerAddress);
            MarketManager marketManager = MarketManager(marketManagerAddress);

            operatorManager.transferOwnership(multiSigAddress);
            vaultManager.transferOwnership(multiSigAddress);
            ledger.transferOwnership(multiSigAddress);
            feeManager.transferOwnership(multiSigAddress);
            marketManager.transferOwnership(multiSigAddress);
        }

        {
            // second change the owner of the proxys
            ProxyAdmin admin = ProxyAdmin(adminAddress);
            ITransparentUpgradeableProxy feeManagerProxy = ITransparentUpgradeableProxy(feeManagerAddress);
            ITransparentUpgradeableProxy marketManagerProxy = ITransparentUpgradeableProxy(marketManagerAddress);
            ITransparentUpgradeableProxy operatorManagerProxy = ITransparentUpgradeableProxy(operatorManagerAddress);
            ITransparentUpgradeableProxy vaultManagerProxy = ITransparentUpgradeableProxy(vaultManagerAddress);
            ITransparentUpgradeableProxy ledgerProxy = ITransparentUpgradeableProxy(ledgerAddress);

            admin.changeProxyAdmin(feeManagerProxy, multiSigAddress);
            admin.changeProxyAdmin(marketManagerProxy, multiSigAddress);
            admin.changeProxyAdmin(operatorManagerProxy, multiSigAddress);
            admin.changeProxyAdmin(vaultManagerProxy, multiSigAddress);
            admin.changeProxyAdmin(ledgerProxy, multiSigAddress);
        }

        vm.stopBroadcast();
        console.log("transfer owner done");
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/Ledger.sol";
import "../utils/BaseScript.s.sol";
import "../utils/ConfigHelper.s.sol";

contract UpgradeLedger is BaseScript, ConfigHelper {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        Envs memory envs = getEnvs();
        string memory env = envs.env;
        string memory network = envs.ledgerNetwork;

        LedgerDepolyData memory config = getLedgerDeployData(env, network);
        address adminAddress = config.proxyAdmin;
        address ledgerAddress = config.ledger;
        console.log("adminAddress: ", adminAddress);
        console.log("ledgerAddress: ", ledgerAddress);

        ProxyAdmin admin = ProxyAdmin(adminAddress);
        ITransparentUpgradeableProxy ledgerProxy = ITransparentUpgradeableProxy(ledgerAddress);

        vm.startBroadcast(orderlyPrivateKey);

        ILedger ledgerImpl = new Ledger();
        admin.upgrade(ledgerProxy, address(ledgerImpl));
        // admin.upgradeAndCall(ledgerProxy, address(ledgerImpl), abi.encodeWithSignature("upgradeCall()"));

        vm.stopBroadcast();
        console.log("upgrade done");
    }
}

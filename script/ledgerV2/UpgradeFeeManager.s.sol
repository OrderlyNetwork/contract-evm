// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/feeManager.sol";
import "../utils/BaseScript.s.sol";
import "../utils/ConfigHelper.s.sol";

contract UpgradeFeeManager is BaseScript, ConfigHelper {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        Envs memory envs = getEnvs();
        string memory env = envs.env;
        string memory network = envs.ledgerNetwork;

        LedgerDepolyData memory config = getLedgerDeployData(env, network);
        address adminAddress = config.proxyAdmin;
        address feeManagerAddress = config.feeManager;
        console.log("adminAddress: ", adminAddress);
        console.log("feeManagerAddress: ", feeManagerAddress);

        ProxyAdmin admin = ProxyAdmin(adminAddress);
        ITransparentUpgradeableProxy feeManagerProxy = ITransparentUpgradeableProxy(feeManagerAddress);

        vm.startBroadcast(orderlyPrivateKey);

        IFeeManager feeManagerImpl = new FeeManager();
        admin.upgrade(feeManagerProxy, address(feeManagerImpl));

        vm.stopBroadcast();
        console.log("upgrade done");
    }
}

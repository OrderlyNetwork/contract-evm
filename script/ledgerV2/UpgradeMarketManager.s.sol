// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/MarketManager.sol";
import "../utils/BaseScript.s.sol";
import "../utils/ConfigHelper.s.sol";

contract UpgradeMarketManager is BaseScript, ConfigHelper {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        Envs memory envs = getEnvs();
        string memory env = envs.env;
        string memory network = envs.ledgerNetwork;

        LedgerDepolyData memory config = getLedgerDeployData(env, network);
        address adminAddress = config.proxyAdmin;
        address marketManagerAddress = config.marketManager;
        console.log("adminAddress: ", adminAddress);
        console.log("marketManagerAddress: ", marketManagerAddress);

        ProxyAdmin admin = ProxyAdmin(adminAddress);
        ITransparentUpgradeableProxy marketManagerProxy = ITransparentUpgradeableProxy(marketManagerAddress);

        vm.startBroadcast(orderlyPrivateKey);

        IMarketManager marketManagerImpl = new MarketManager();
        admin.upgrade(marketManagerProxy, address(marketManagerImpl));

        vm.stopBroadcast();
    }
}

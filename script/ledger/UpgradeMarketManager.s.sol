// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/MarketManager.sol";

contract UpgradeMarketManager is Script {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        address adminAddress = vm.envAddress("LEDGER_PROXY_ADMIN");
        address marketManagerAddress = vm.envAddress("MARKET_MANAGER_ADDRESS");

        ProxyAdmin admin = ProxyAdmin(adminAddress);
        ITransparentUpgradeableProxy marketManagerProxy = ITransparentUpgradeableProxy(marketManagerAddress);

        vm.startBroadcast(orderlyPrivateKey);

        IMarketManager marketManagerImpl = new MarketManager();
        admin.upgrade(marketManagerProxy, address(marketManagerImpl));
        // admin.upgradeAndCall(marketManagerProxy, address(marketManagerImpl), abi.encodeWithSignature("initialize()"));

        vm.stopBroadcast();
    }
}

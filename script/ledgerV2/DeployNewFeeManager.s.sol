// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/feeManager.sol";
import "../utils/BaseScript.s.sol";
import "../utils/ConfigHelper.s.sol";

contract DeployNewFeeManager is BaseScript, ConfigHelper {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        Envs memory envs = getEnvs();
        string memory env = envs.env;
        string memory network = envs.ledgerNetwork;

        LedgerDepolyData memory config = getLedgerDeployData(env, network);
        address feeManagerAddress = config.feeManager;
        console.log("feeManagerAddress: ", feeManagerAddress);

        vm.startBroadcast(orderlyPrivateKey);
        IFeeManager feeManagerImpl = new FeeManager();
        console.log("new feeManagerImplAddress: ", address(feeManagerImpl));
        vm.stopBroadcast();
        console.log("deply done");
    }
}

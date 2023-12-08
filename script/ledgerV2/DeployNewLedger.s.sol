// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/Ledger.sol";
import "../utils/BaseScript.s.sol";
import "../utils/ConfigHelper.s.sol";

contract DeployNewLedger is BaseScript, ConfigHelper {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        Envs memory envs = getEnvs();
        string memory env = envs.env;
        string memory network = envs.ledgerNetwork;

        LedgerDeployData memory config = getLedgerDeployData(env, network);
        address ledgerAddress = config.ledger;
        console.log("ledgerAddress: ", ledgerAddress);

        vm.startBroadcast(orderlyPrivateKey);
        ILedger ledgerImpl = new Ledger();
        console.log("new ledgerImplAddress: ", address(ledgerImpl));
        vm.stopBroadcast();
        console.log("deploy done");
    }
}

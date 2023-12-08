// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../../src/Ledger.sol";
import "../utils/BaseScript.s.sol";
import "../utils/ConfigHelper.s.sol";

contract SetCrossChainManager is BaseScript, ConfigHelper {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        address ledgerCrossChainManagerAddress = vm.envAddress("LEDGER_CROSS_CHAIN_MANAGER_ADDRESS"); // FIXME
        Envs memory envs = getEnvs();
        string memory env = envs.env;
        string memory network = envs.ledgerNetwork;

        LedgerDeployData memory config = getLedgerDeployData(env, network);
        address adminAddress = config.proxyAdmin;
        address ledgerAddress = config.ledger;
        console.log("adminAddress: ", adminAddress);
        console.log("ledgerAddress: ", ledgerAddress);

        vm.startBroadcast(orderlyPrivateKey);

        ILedger ledger = Ledger(ledgerAddress);
        ledger.setCrossChainManager(ledgerCrossChainManagerAddress);

        vm.stopBroadcast();
        console.log("setCrossChainManager done");
    }
}

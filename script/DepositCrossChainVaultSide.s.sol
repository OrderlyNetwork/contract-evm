// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../lib/crosschain/contracts/CrossChainRelay.sol";
import "../src/VaultCrossChainManager.sol";

contract DepositCrossChainVaultSide is Script{
    function run() external {
        //uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        uint256 fujiPrivateKey = vm.envUint("FUJI_PRIVATE_KEY");
        address mumbaiLedgerRelay = vm.envAddress("MUMBAI_LEDGER_RELAY_ADDRESS");
        address vaultRelay = vm.envAddress("VAULT_RELAY_ADDRESS");
        //address ledgerCrossChainManager = vm.envAddress("LEDGER_CROSS_CHAIN_MANAGER_ADDRESS");
        address mumbaiLedgerCrossChainManager = vm.envAddress("MUMBAI_LEDGER_CROSS_CHAIN_MANAGER_ADDRESS");
        address vaultCrossChainManager = vm.envAddress("VAULT_CROSS_CHAIN_MANAGER_ADDRESS");
        uint256 vaultSideChainId = 43113;
        uint256 ledgerSideChainId = 986532;
        uint256 mumbaiLedgerChainId = 80001;
        uint16 vaultLzChainId = 10106;
        uint16 ledgerLzChainId = 10174;
        uint16 mumbaiLedgerLzChainId = 10109;
        // 100 native token
        //uint256 ledgerTransferAmount = 100_000_000_000_000_000_000;
        // 1 native token
        uint256 vaultTransferAmount = 1_000_000_000_000_000_000;

        vm.startBroadcast(fujiPrivateKey);

        CrossChainRelay relay = CrossChainRelay(payable(vaultRelay));

        bytes memory vaultLzPath = abi.encodePacked(mumbaiLedgerRelay, vaultRelay);

        relay.addChainIdMapping(ledgerSideChainId, ledgerLzChainId);
        relay.addChainIdMapping(vaultSideChainId, vaultLzChainId);
        relay.addChainIdMapping(mumbaiLedgerChainId, mumbaiLedgerLzChainId);
        relay.setSrcChainId(vaultSideChainId);
        //relay.setTrustedRemote(ledgerLzChainId, vaultLzPath);
        relay.setTrustedRemote(mumbaiLedgerLzChainId, vaultLzPath);
        relay.addCaller(vaultCrossChainManager);

        payable(vaultRelay).call{value: vaultTransferAmount}("");

        VaultCrossChainManager vaultCrossChainManagerInstance = VaultCrossChainManager(payable(vaultCrossChainManager));
        vaultCrossChainManagerInstance.setChainId(vaultSideChainId);
        vaultCrossChainManagerInstance.setCrossChainRelay(vaultRelay);
        vaultCrossChainManagerInstance.setLedgerCrossChainManager(mumbaiLedgerChainId, mumbaiLedgerCrossChainManager);

        vm.stopBroadcast();
    }
}

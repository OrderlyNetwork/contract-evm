// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../lib/crosschain/contracts/CrossChainRelay.sol";
import "../src/LedgerCrossChainManager.sol";

contract DepositCrossChainLedgerMumbai is Script{
    function run() external {
        //uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        //uint256 fujiPrivateKey = vm.envUint("FUJI_PRIVATE_KEY");
        uint256 mumbaiPrivateKey = vm.envUint("MUMBAI_PRIVATE_KEY");
        //address ledgerRelay = vm.envAddress("LEDGER_RELAY_ADDRESS");
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
        // 2 native token
        //uint256 vaultTransferAmount = 2_000_000_000_000_000_000;
        // 2 native token
        uint256 mumbaiLedgerTransferAmount = 2_000_000_000_000_000_000;

        vm.startBroadcast(mumbaiPrivateKey);

        CrossChainRelay relay = CrossChainRelay(payable(mumbaiLedgerRelay));

        bytes memory ledgerLzPath = abi.encodePacked(vaultRelay, mumbaiLedgerRelay);

        relay.addChainIdMapping(ledgerSideChainId, ledgerLzChainId);
        relay.addChainIdMapping(vaultSideChainId, vaultLzChainId);
        relay.addChainIdMapping(mumbaiLedgerChainId, mumbaiLedgerLzChainId);
        relay.setSrcChainId(mumbaiLedgerChainId);
        relay.setTrustedRemote(vaultLzChainId, ledgerLzPath);
        relay.addCaller(mumbaiLedgerCrossChainManager);

        payable(mumbaiLedgerRelay).call{value: mumbaiLedgerTransferAmount}("");

        LedgerCrossChainManager ledgerCrossChainManagerInstance = LedgerCrossChainManager(payable(mumbaiLedgerCrossChainManager));
        ledgerCrossChainManagerInstance.setChainId(mumbaiLedgerChainId);
        ledgerCrossChainManagerInstance.setCrossChainRelay(mumbaiLedgerRelay);
        ledgerCrossChainManagerInstance.setVaultCrossChainManager(vaultSideChainId, vaultCrossChainManager);

        vm.stopBroadcast();
    }
}

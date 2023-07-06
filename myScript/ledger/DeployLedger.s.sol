// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../../src/OperatorManager.sol";
import "../../src/Ledger.sol";
import "../../src/VaultManager.sol";
import "../../src/FeeManager.sol";
import "../../src/MarketManager.sol";

contract DeployLedger is Script {
    bytes32 constant BROKER_HASH = 0x083098c593f395bea1de45dda552d9f14e8fcb0be3faaa7a1903c5477d7ba7fd; // woofi_dex
    bytes32 constant TOKEN_HASH = 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa; // USDC
    uint256 constant CHAIN_ID = 43113; // fuji

    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        address operatorAddress = vm.envAddress("OPERATOR_ADDRESS");
        address ledgerCrossChainManagerAddress = vm.envAddress("LEDGER_CROSS_CHAIN_MANAGER_ADDRESS");
        vm.startBroadcast(orderlyPrivateKey);

        ILedgerCrossChainManager ledgerCrossChainManager = ILedgerCrossChainManager(ledgerCrossChainManagerAddress);
        IOperatorManager operatorManager = new OperatorManager();
        IVaultManager vaultManager = new VaultManager();
        ILedger ledger = new Ledger();
        IFeeManager feeManager = new FeeManager();
        IMarketManager marketManager = new MarketManager();

        ledger.setOperatorManagerAddress(address(operatorManager));
        ledger.setCrossChainManager(address(ledgerCrossChainManager));
        ledger.setVaultManager(address(vaultManager));
        ledger.setFeeManager(address(feeManager));
        ledger.setMarketManager(address(marketManager));

        operatorManager.setOperator(operatorAddress);
        operatorManager.setLedger(address(ledger));

        vaultManager.setLedgerAddress(address(ledger));
        vaultManager.setAllowedBroker(BROKER_HASH, true);
        vaultManager.setAllowedToken(TOKEN_HASH, CHAIN_ID, true);

        feeManager.setLedgerAddress(address(ledger));

        marketManager.setLedgerAddress(address(ledger));

        ledgerCrossChainManager.setLedger(address(ledger));
        // ledgerCrossChainManager.setOperatorManager(address(operatorManager));

        vm.stopBroadcast();
    }
}
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../../src/OperatorManager.sol";
import "../../src/Ledger.sol";
import "../../src/VaultManager.sol";
import "../../src/LedgerCrossChainManager.sol";
import "../../src/FeeManager.sol";
import "../../src/MarketManager.sol";

contract DeployLedger is Script {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        address operatorAddress = vm.envAddress("OPERATOR_ADDRESS");
        address ledgerCrossChainManagerAddress = vm.envAddress("LedgerCrossChainManager_ADDRESS");
        vm.startBroadcast(orderlyPrivateKey);

        ILedgerCrossChainManager ledgerCrossChainManager =
            LedgerCrossChainManager(payable(ledgerCrossChainManagerAddress));
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

        ledgerCrossChainManager.setLedger(address(ledger));
        ledgerCrossChainManager.setOperatorManager(address(operatorManager));

        vaultManager.setLedgerAddress(address(ledger));

        feeManager.setLedgerAddress(address(ledger));

        marketManager.setLedgerAddress(address(ledger));

        vm.stopBroadcast();
    }
}

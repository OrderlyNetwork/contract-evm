// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../src/Ledger.sol";


contract CheckLedger is Script{
    event Manager(address);
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        address ledger = 0xAbCA777A0439Fc13ff7bA472d85DBb82D83E7738;
        vm.startBroadcast(orderlyPrivateKey);

        Ledger ledgerInstance = Ledger(payable(ledger));

        address manager = ledgerInstance.crossChainManagerAddress();

        emit Manager(manager);
        vm.stopBroadcast();
    }
}

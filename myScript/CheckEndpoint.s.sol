// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../lib/crosschain/contracts/CrossChainRelay.sol";
import "../src/VaultCrossChainManager.sol";
import "../lib/crosschain/contracts/layerzero/interfaces/ILayerZeroEndpoint.sol";


contract CheckEndpoint is Script{
    event HasPayload(bool);
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("ORDERLY_PRIVATE_KEY");
        address endpoint = vm.envAddress("ORDERLY_ENDPOINT");
        address vaultRelay = vm.envAddress("VAULT_RELAY_ADDRESS");
        address ledgerRelay = vm.envAddress("LEDGER_RELAY_ADDRESS");
        vm.startBroadcast(orderlyPrivateKey);
        ILayerZeroEndpoint endpointInstance = ILayerZeroEndpoint(payable(endpoint));

        uint16 srcChainId = 10106;
        bytes memory lzPath = abi.encodePacked(vaultRelay, ledgerRelay);

        bool has = endpointInstance.hasStoredPayload(srcChainId, lzPath);
        emit HasPayload(has);

        vm.stopBroadcast();
    }
}

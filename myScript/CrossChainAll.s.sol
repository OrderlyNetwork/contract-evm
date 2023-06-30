// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../lib/crosschain/contracts/CrossChainRelay.sol";
import "../src/VaultCrossChainManager.sol";
import "../src/LedgerCrossChainManager.sol";
import "./Utils.sol";
import "./CrossChainConfig.sol";

contract RelayWithdrawLedgerMumbai is Script{
    using StringCompare for string;

    function run() external {
        string memory method = vm.envString("CROSS_CHAIN_SCRIPT_METHOD");
        string memory crosschainOption = vm.envString("CROSS_CHAIN_OPTION");
        string memory currentSide = vm.envString("CROSS_CHAIN_CURRENT_SIDE");
        CrossChainConfig allConfig = new CrossChainConfig();
        CrossChainConfig.ChainConfig memory config = allConfig.getChainConfig(crosschainOption);
        uint256 vaultPrivateKey = getPrivateKey(config.vaultNetwork);
        uint256 ledgerPrivateKey = getPrivateKey(config.ledgerNetwork);

        (
            address relayAddress,
            address otherRelayAddress,
            address crossChainManagerAddress,
            address otherCrossChainManagerAddress,
            string memory network,
            uint256 srcChainId,
            uint16 srcLzChainId,
            uint256 dstChainId,
            uint16 dstLzChainId
        ) = getCrossChainInfo(currentSide, config);

        /* Call Steps
            1. Init
                1. deploy relay(ledger), relay(vault), ledgerCrossChainManager, vaultCrossChainManager
                2. initRelay
                3. initCrossChainManager
            2. WithdrawRelay
            3. transferRelay
            4. SetGasMapping
            5. Update relay
                1. init relay
                2. update relay on cross chain manager
                3. update relay on other side
            6. update cross chain manager
                1. init cross chain manager
                2. update cross chain manager on relay
                3. update cross chain manager on other side
            7. forceResume
         */
        vm.startBroadcast(getPrivateKey(network));

        // initialize cross chain
        if (method.compare("init")) {
            initRelay(relayAddress, otherRelayAddress, crossChainManagerAddress, srcChainId, dstLzChainId, allConfig);
            initCrossChainManager(currentSide, relayAddress, crossChainManagerAddress, otherCrossChainManagerAddress, srcChainId, dstChainId);
        } else if (method.compare("withdrawRelay")) {
            withdrawRelay(relayAddress, network);
        } else if (method.compare("transferRelay")) {
            transferRelay(relayAddress);
        } else if (method.compare("setGasMapping")) {
            setGasMapping(crosschainOption, allConfig, relayAddress);

        // when you deploy a new relay, update relay
        } else if (method.compare("updateRelay")) {
            initRelay(relayAddress, otherRelayAddress, crossChainManagerAddress, srcChainId, dstLzChainId, allConfig);
            updateRelayOnCrossChainManager(currentSide, relayAddress, crossChainManagerAddress);
        } else if (method.compare("updateOtherSideRelay")) {
            updateOtherSideRelay(relayAddress, otherRelayAddress, dstLzChainId);

        // when deploy a new cross chain manager, update cross chain manager
        } else if (method.compare("updateCrossChainManager")) {
            initCrossChainManager(currentSide, relayAddress, crossChainManagerAddress, otherCrossChainManagerAddress, srcChainId, dstChainId);
            updateCrossChainManagerOnRelay(relayAddress, crossChainManagerAddress);
        } else if (method.compare("updateOtherSideCrossChainManager")) {
            updateOtherSideCrossChainManager(currentSide, crossChainManagerAddress, otherCrossChainManagerAddress, dstChainId);
        } else if (method.compare("forceResume")) {
            forceResumeReceive(relayAddress, otherRelayAddress, dstLzChainId);
        } else if (method.compare("deposit")) {
        } else {
            revert("Invalid method");
        }

        vm.stopBroadcast();
    }

    function withdrawRelay(address relayAddress, string memory network) internal {


        address signerAddress = vm.addr(getPrivateKey(network));
        CrossChainRelay relay = CrossChainRelay(payable(relayAddress));
        uint256 balance = relayAddress.balance;

        relay.withdrawNativeToken(payable(signerAddress), balance);
    }

    function transferRelay(address relayAddress) internal {
        uint256 transferAmount = vm.envUint("RELAY_TRANSFER_AMOUNT");

        (bool ret, ) = payable(relayAddress).call{value: transferAmount}("");
        require(ret, "Transfer relay failed");
    }

    function initRelay(address relayAddress, address otherRelayAddress, address crossChainManagerAddress, uint256 srcChainId, uint16 dstLzChainId, CrossChainConfig allConfig ) internal {

        CrossChainRelay relay = CrossChainRelay(payable(relayAddress));

        uint256[] memory chainIds = allConfig.getChainIds();

        for (uint256 i = 0; i < chainIds.length; i++) {
            uint256 chainId = chainIds[i];
            uint16 lzChainId = allConfig._chainId2LzIdMapping(chainId);
            relay.addChainIdMapping(chainId, lzChainId);
        }
        bytes memory lzPath = abi.encodePacked(otherRelayAddress, relayAddress);
        relay.setSrcChainId(srcChainId);
        relay.setTrustedRemote(dstLzChainId, lzPath);
        relay.addCaller(crossChainManagerAddress);

        transferRelay(relayAddress);

    }
    function updateRelayOnCrossChainManager(string memory currentSide, address relayAddress, address crossChainManagerAddress) internal {
        if (currentSide.compare("vault")) {
            VaultCrossChainManager vaultCrossChainManager = VaultCrossChainManager(payable(crossChainManagerAddress));
            vaultCrossChainManager.setCrossChainRelay(relayAddress);
        } else {
            LedgerCrossChainManager ledgerCrossChainManager = LedgerCrossChainManager(payable(crossChainManagerAddress));
            ledgerCrossChainManager.setCrossChainRelay(relayAddress);
        }
    }

    function updateOtherSideRelay(address relayAddress, address otherRelayAddress, uint16 dstLzChainId) internal {
        CrossChainRelay relay = CrossChainRelay(payable(relayAddress));
        bytes memory lzPath = abi.encodePacked(otherRelayAddress, relayAddress);
        relay.setTrustedRemote(dstLzChainId, lzPath);
    }

    function initCrossChainManager(string memory currentSide, address relayAddress, address crossChainManagerAddress, address otherCrossChainManagerAddress, uint256 srcChainId, uint256 dstChainId) internal {
        if (currentSide.compare("vault")) {

            VaultCrossChainManager vaultCrossChainManager = VaultCrossChainManager(payable(crossChainManagerAddress));

            vaultCrossChainManager.setChainId(srcChainId);
            vaultCrossChainManager.setCrossChainRelay(relayAddress);
            vaultCrossChainManager.setLedgerCrossChainManager(dstChainId, otherCrossChainManagerAddress);
        } else {
            LedgerCrossChainManager ledgerCrossChainManager = LedgerCrossChainManager(payable(crossChainManagerAddress));

            ledgerCrossChainManager.setChainId(srcChainId);
            ledgerCrossChainManager.setCrossChainRelay(relayAddress);
            ledgerCrossChainManager.setVaultCrossChainManager(dstChainId, otherCrossChainManagerAddress);

        }
    }

    function updateCrossChainManagerOnRelay(address relayAddress, address crossChainManagerAddress) internal {
        CrossChainRelay relay = CrossChainRelay(payable(relayAddress));
        relay.addCaller(crossChainManagerAddress);
    }

    function updateOtherSideCrossChainManager(string memory currentSide, address crossChainManagerAddress, address otherCrossChainManagerAddress, uint256 dstChainId) internal {
        if (currentSide.compare("vault")) {
            VaultCrossChainManager vaultCrossChainManager = VaultCrossChainManager(payable(otherCrossChainManagerAddress));
            vaultCrossChainManager.setLedgerCrossChainManager(dstChainId, crossChainManagerAddress);
        } else {
            LedgerCrossChainManager ledgerCrossChainManager = LedgerCrossChainManager(payable(otherCrossChainManagerAddress));
            ledgerCrossChainManager.setVaultCrossChainManager(dstChainId, crossChainManagerAddress);
        }
    }


    function setGasMapping(string memory crosschainOption, CrossChainConfig allConfig, address relayAddress) internal {
        CrossChainConfig.ChainConfig memory config = allConfig.getChainConfig(crosschainOption);

        CrossChainRelay relay = CrossChainRelay(payable(relayAddress));

        relay.addFlowGasLimitMapping(0, 3000000);
        relay.addFlowGasLimitMapping(1, 3000000);
        relay.addFlowGasLimitMapping(2, 3000000);
    }

    function forceResumeReceive(address relayAddress , address otherRelayAddress, uint16 dstLzChainId) internal {
        CrossChainRelay relay = CrossChainRelay(payable(relayAddress));
        bytes memory lzPath = abi.encodePacked(otherRelayAddress, relayAddress);
        relay.forceResumeReceive(dstLzChainId, lzPath);
    }

    function getPrivateKey(string memory network) internal returns (uint256) {
        if (network.compare("fuji")) {
            return vm.envUint("FUJI_PRIVATE_KEY");
        } else if (network.compare("mumbai")) {
            return vm.envUint("MUMBAI_PRIVATE_KEY");
        } else {
            revert("Invalid network");
        }
    }

    function getCrossChainInfo(string memory currentSide, CrossChainConfig.ChainConfig memory config) internal pure returns (address, address, address, address, string memory, uint256, uint16, uint256, uint16) {
        if (currentSide.compare("vault")) {
            return (
                config.vaultRelay,
                config.ledgerRelay,
                config.vaultCrossChainManager, 
                config.ledgerCrossChainManager, 
                config.vaultNetwork, 
                config.vaultChainId, 
                config.vaultLzChainId, 
                config.ledgerChainId, 
                config.ledgerLzChainId
            );
        } else if (currentSide.compare("ledger")){
            return (
                config.ledgerRelay,
                config.vaultRelay,
                config.ledgerCrossChainManager,
                config.vaultCrossChainManager,
                config.ledgerNetwork,
                config.ledgerChainId,
                config.ledgerLzChainId,
                config.vaultChainId,
                config.vaultLzChainId
            );
        } else {
            revert("Invalid currentSide");
        }
    }
}

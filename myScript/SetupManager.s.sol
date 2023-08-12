// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./BaseScript.s.sol";

import "../src/LedgerCrossChainManagerUpgradeable.sol";
import "../src/VaultCrossChainManagerUpgradeable.sol";
import "../src/CrossChainManagerProxy.sol";

contract SetupManager is BaseScript {
    using StringCompare for string;

    function run() external {
        string memory network = vm.envString("CURRENT_NETWORK");
        string memory currentSide = vm.envString("CURRENT_SIDE");
        string memory method = vm.envString("CALL_METHOD");
        uint256 privateKey = getPrivateKey(network);

        vm.startBroadcast(privateKey);

        if (method.compare("setup")) {
            address managerAddress = getManagerProxyAddress(network);
            address relayAddress = getRelayProxyAddress(network);
            uint256 chainId = getChainId(network);
            if (currentSide.compare("ledger")) {
                address operatorAddress = getOperatorManagerAddress(network);
                address ledgerAddress = getLedgerAddress(network);
                ledgerSetup(managerAddress, relayAddress, operatorAddress, ledgerAddress, chainId);
            } else if (currentSide.compare("vault")) {
                string memory ledgerNetwork = vm.envString("LEDGER_NETWORK");
                uint256 ledgerChainId = getChainId(ledgerNetwork);
                address ledgerManagerAddress = getManagerProxyAddress(ledgerNetwork);
                address vaultAddress = getVaultAddress(network);
                vaultSetup(managerAddress, relayAddress, ledgerManagerAddress, vaultAddress, chainId, ledgerChainId);
            } else {
                revert("Invalid side");
            }
        } else if (method.compare("addVault")) {
            string memory addVaultNetwork = vm.envString("ADD_VAULT_NETWORK");
            address vaultManagerAddress = getManagerProxyAddress(addVaultNetwork);
            uint256 vaultChainId = getChainId(addVaultNetwork);
            address managerAddress = getManagerProxyAddress(network);
            addVaultManagerToLedgerManager(managerAddress, vaultManagerAddress, vaultChainId);
        } else if (method.compare("setLedger")) {

        } else if (method.compare("test")) {
            sendTestWithdraw(network);
        } else {
            revert("Invalid method");
        }

        vm.stopBroadcast();
    }

    function vaultSetup(address managerAddress, address relayAddress, address ledgerManagerAddress, address vaultAddress, uint256 chainId, uint256 ledgerChainId) internal {
        VaultCrossChainManagerUpgradeable manager = VaultCrossChainManagerUpgradeable(payable(managerAddress));
        manager.setChainId(chainId);
        manager.setCrossChainRelay(relayAddress);
        manager.setLedgerCrossChainManager(ledgerChainId, ledgerManagerAddress);
        manager.setVault(vaultAddress);
    }

    function ledgerSetup(address managerAddress, address relayAddress, address operatorAddress, address ledgerAddress, uint256 chainId) internal {
        LedgerCrossChainManagerUpgradeable manager = LedgerCrossChainManagerUpgradeable(payable(managerAddress));
        manager.setChainId(chainId);
        manager.setCrossChainRelay(relayAddress);
        manager.setOperatorManager(operatorAddress);
        manager.setLedger(ledgerAddress);

        // subnet USDC decimal
        manager.setTokenDecimal(0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa, 986532, 6);
        manager.setTokenDecimal(0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa, 986533, 4);
        manager.setTokenDecimal(0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa, 986534, 6);
        // fuji USDC decimal
        manager.setTokenDecimal(0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa, 43113, 6);
    }

    function addVaultManagerToLedgerManager(address ledgerManagerAddress, address vaultManagerAddress, uint256 vaultChainId) internal {
        LedgerCrossChainManagerUpgradeable ledgerManager = LedgerCrossChainManagerUpgradeable(payable(ledgerManagerAddress));
        ledgerManager.setVaultCrossChainManager(vaultChainId, vaultManagerAddress);
    }

    function sendTestWithdraw(string memory network) internal {
        address managerProxy = getManagerProxyAddress(network);
        LedgerCrossChainManagerUpgradeable manager = LedgerCrossChainManagerUpgradeable(payable(managerProxy));

        uint256 dstChainId = getChainId(vm.envString("TARGET_NETWORK"));
        manager.sendTestWithdraw(dstChainId);
    }

    function setLedger(string memory network) internal {
        string memory ledgerNetwork = vm.envString("LEDGER_NETWORK");
        address ledgerProxy = getManagerProxyAddress(ledgerNetwork);
        address vaultProxy = getManagerProxyAddress(network);
        uint256 ledgerChainId = getChainId(ledgerNetwork);

        VaultCrossChainManagerUpgradeable vaultManager = VaultCrossChainManagerUpgradeable(payable(vaultProxy));
        vaultManager.setLedgerCrossChainManager(ledgerChainId, ledgerProxy);
    }
}
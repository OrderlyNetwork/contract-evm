// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./BaseScript.s.sol";

import "../src/LedgerCrossChainManagerUpgradeable.sol";
import "../src/VaultCrossChainManagerUpgradeable.sol";
import "../src/CrossChainManagerProxy.sol";

contract DeployAndUpgradeManager is BaseScript {
    using StringCompare for string;

    event Deployed(string contractName, address deployAddress);

    function run() external {
        string memory network = vm.envString("CURRENT_NETWORK");
        string memory currentSide = vm.envString("CURRENT_SIDE");
        string memory method = vm.envString("CALL_METHOD");
        uint256 privateKey = getPrivateKey(network);

        vm.startBroadcast(privateKey);

        if (method.compare("deploy")) {
            deploy(currentSide);
        } else if (method.compare("upgrade")) {
            upgrade(currentSide, network);
        } else {
            revert("Invalid method");
        }
        vm.stopBroadcast();
    }

    function deploy(string memory side) internal {
        if (side.compare("ledger")) {
            deployLedgerManager();
        } else if (side.compare("vault")) {
            deployVaultManager();
        } else {
            revert("Invalid side");
        }
    }

    function upgrade(string memory side, string memory network) internal {
        address proxyAddress = getManagerProxyAddress(network);
        if (side.compare("ledger")) {
            upgradeLedgerManager(proxyAddress);
        } else if (side.compare("vault")) {
            upgradeVaultManager(proxyAddress);
        } else {
            revert("Invalid side");
        }
    }

    function deployVaultManager() internal {
        // deploy vault manager
        VaultCrossChainManagerUpgradeable manager = new VaultCrossChainManagerUpgradeable();
        // deploy proxy
        CrossChainManagerProxy proxy = new CrossChainManagerProxy(address(manager), "");
        // initialize proxy
        VaultCrossChainManagerUpgradeable proxyManager = VaultCrossChainManagerUpgradeable(payable(address(proxy)));
        proxyManager.initialize();

        // logging deploy address
        emit Deployed("VaultCrossChainManagerUpgradeable", address(manager));
        emit Deployed("CrossChainManagerProxy", address(proxy));
    }

    function deployLedgerManager() internal {
        // deploy ledger manager
        LedgerCrossChainManagerUpgradeable manager = new LedgerCrossChainManagerUpgradeable();
        // deploy proxy
        CrossChainManagerProxy proxy = new CrossChainManagerProxy(address(manager), "");
        // initialize proxy
        LedgerCrossChainManagerUpgradeable proxyManager = LedgerCrossChainManagerUpgradeable(payable(address(proxy)));
        proxyManager.initialize();

        // logging deploy address
        emit Deployed("LedgerCrossChainManagerUpgradeable", address(manager));
        emit Deployed("CrossChainManagerProxy", address(proxy));
    }

    function upgradeVaultManager(address proxyAddress) internal {
        // deploy new manager
        VaultCrossChainManagerUpgradeable newManager = new VaultCrossChainManagerUpgradeable();
        // upgrade proxy
        VaultCrossChainManagerUpgradeable proxyManager = VaultCrossChainManagerUpgradeable(payable(proxyAddress));
        proxyManager.upgradeTo(address(newManager));

        // logging deploy address
        emit Deployed("VaultCrossChainManagerUpgradeable", address(newManager));
    }

    function upgradeLedgerManager(address proxyAddress) internal {
        // deploy new manager
        LedgerCrossChainManagerUpgradeable newManager = new LedgerCrossChainManagerUpgradeable();
        // upgrade proxy
        LedgerCrossChainManagerUpgradeable proxyManager = LedgerCrossChainManagerUpgradeable(payable(proxyAddress));
        proxyManager.upgradeTo(address(newManager));

        // logging deploy address
        emit Deployed("LedgerCrossChainManagerUpgradeable", address(newManager));
    }
}
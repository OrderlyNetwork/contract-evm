// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../../src/vaultSide/Vault.sol";
import "../../script/utils/ConfigHelper.s.sol";

contract OnchainVault is ConfigHelper, Test {
    uint256 mainnetArbitrumFork;
    uint256 mainnetOptimismFork;
    uint256 mainnetPolygonFork;
    uint256 stagingArbitrumFork;
    uint256 stagingOptimismFork;
    uint256 stagingPolygonFork;
    bytes32 constant BROKER_ID_1 = 0x6ca2f644ef7bd6d75953318c7f2580014941e753b3c6d54da56b3bf75dd14dfc; // woofi_pro
    bytes32 constant BROKER_ID_2 = 0xd6c66cad06fe14fdb6ce9297d80d32f24d7428996d0045cbf90cc345c677ba16; // root
    bytes32 constant BROKER_ID_3 = 0x95d85ced8adb371760e4b6437896a075632fbd6cefe699f8125a8bc1d9b19e5b; // orderly
    bytes32 constant TOKEN_0 = 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa; // USDC

    function setUp() public {
        // provent env not found error
        string memory RPC_URL_ARBITRUM = vm.envString("RPC_URL_ARBITRUM");
        string memory RPC_URL_ARBITRUMSEPOLIA = vm.envString("RPC_URL_ARBITRUMSEPOLIA");
        string memory RPC_URL_OP = vm.envString("RPC_URL_OP");
        string memory RPC_URL_OPSEPOLIA = vm.envString("RPC_URL_OPSEPOLIA");
        string memory RPC_URL_POLYGON = vm.envString("RPC_URL_POLYGON");
        string memory RPC_URL_MUMBAI = vm.envString("RPC_URL_MUMBAI");
        mainnetArbitrumFork = vm.createFork(RPC_URL_ARBITRUM);
        mainnetOptimismFork = vm.createFork(RPC_URL_OP);
        mainnetPolygonFork = vm.createFork(RPC_URL_POLYGON);
        stagingArbitrumFork = vm.createFork(RPC_URL_ARBITRUMSEPOLIA);
        stagingOptimismFork = vm.createFork(RPC_URL_OPSEPOLIA);
        stagingPolygonFork = vm.createFork(RPC_URL_MUMBAI);
    }

    function test_onchain_vault_arbitrum_staging() external {
        vm.selectFork(stagingArbitrumFork);
        string memory env = "staging";
        string memory network = "arbitrumsepolia";
        _test_onchain_vault(env, network);
    }

    function test_onchain_vault_optimism_staging() external {
        vm.selectFork(stagingOptimismFork);
        string memory env = "staging";
        string memory network = "opsepolia";
        _test_onchain_vault(env, network);
    }

    function test_onchain_vault_polygon_staging() external {
        vm.selectFork(stagingPolygonFork);
        string memory env = "staging";
        string memory network = "polygonmumbai";
        _test_onchain_vault(env, network);
    }

    function test_onchain_vault_arbitrum_mainnet() external {
        vm.selectFork(mainnetArbitrumFork);
        string memory env = "mainnet";
        string memory network = "arbitrum";
        _test_onchain_vault(env, network);
    }

    function test_onchain_vault_optimism_mainnet() external {
        vm.selectFork(mainnetOptimismFork);
        string memory env = "mainnet";
        string memory network = "op";
        _test_onchain_vault(env, network);
    }

    function test_onchain_vault_polygon_mainnet() external {
        vm.selectFork(mainnetPolygonFork);
        string memory env = "mainnet";
        string memory network = "polygon";
        _test_onchain_vault(env, network);
    }

    function _test_onchain_vault(string memory env, string memory network) internal {
        VaultDeployData memory config = getVaultDeployData(env, network);
        address vaulAddress = config.vault;
        console.log("vaultAddress: ", vaulAddress);
        IVault vault = IVault(vaulAddress);
        // brokerId
        bytes32[] memory allAllowedBroker = vault.getAllAllowedBroker();
        console2.log("allAllowedBroker length: ", allAllowedBroker.length);
        bool foundBroker1 = false;
        bool foundBroker2 = false;
        bool foundBroker3 = false;
        for (uint256 i = 0; i < allAllowedBroker.length; i++) {
            console2.logBytes32(allAllowedBroker[i]);
            if (BROKER_ID_1 == allAllowedBroker[i]) {
                foundBroker1 = true;
            } else if (BROKER_ID_2 == allAllowedBroker[i]) {
                foundBroker2 = true;
            } else if (BROKER_ID_3 == allAllowedBroker[i]) {
                foundBroker3 = true;
            }
        }
        assertGe(allAllowedBroker.length, 3); // at least 3 brokers is set
        assertTrue(foundBroker1);
        assertTrue(foundBroker2);
        assertTrue(foundBroker3);
        // token
        bytes32[] memory allAllowedToken = vault.getAllAllowedToken();
        console2.log("allAllowedToken length: ", allAllowedToken.length);
        for (uint256 i = 0; i < allAllowedToken.length; i++) {
            console2.logBytes32(allAllowedToken[i]);
        }
        assertEq(allAllowedToken.length, 1); // only 1 token is set
        assertEq(allAllowedToken[0], TOKEN_0);
    }
}

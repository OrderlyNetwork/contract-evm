// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../../src/VaultManager.sol";
import "../../script/utils/ConfigHelper.s.sol";

contract OnchainLedgerVaultManager is ConfigHelper, Test {
    uint256 mainnetFork;
    uint256 stagingFork;
    bytes32 constant BROKER_ID_1 = 0x6ca2f644ef7bd6d75953318c7f2580014941e753b3c6d54da56b3bf75dd14dfc; // woofi_pro
    bytes32 constant BROKER_ID_2 = 0xd6c66cad06fe14fdb6ce9297d80d32f24d7428996d0045cbf90cc345c677ba16; // root
    bytes32 constant BROKER_ID_3 = 0x95d85ced8adb371760e4b6437896a075632fbd6cefe699f8125a8bc1d9b19e5b; // orderly
    bytes32 constant TOKEN_0 = 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa; // USDC
    bytes32 constant PERP_BTC_USDC = 0x5a8133e52befca724670dbf2cade550c522c2410dd5b1189df675e99388f509d; // PERP_BTC_USDC
    bytes32 constant PERP_ETH_USDC = 0x7e83089239db756ee233fa8972addfea16ae653db0f692e4851aed546b21caeb; // PERP_ETH_USDC
    bytes32 constant PERP_WOO_USDC = 0x5d0471b083610a6f3b572fc8b0f759c5628e74159816681fb7d927b9263de60b; // PERP_WOO_USDC
    bytes32 constant PERP_TIA_USDC = 0xb5ec44c9e46c5ae2fa0473eb8c466c97ec83dd5f4eddf66f31e83b512cff503c; // PERP_TIA_USDC

    function setUp() public {
        // provent env not found error
        string memory RPC_URL_ORDERLYMAIN = vm.envString("RPC_URL_ORDERLYMAIN");
        string memory RPC_URL_ORDERLYOP = vm.envString("RPC_URL_ORDERLYOP");
        mainnetFork = vm.createFork(RPC_URL_ORDERLYMAIN);
        stagingFork = vm.createFork(RPC_URL_ORDERLYOP);
    }

    function test_onchain_vaultManager_staging() external {
        vm.selectFork(stagingFork);
        string memory env = "staging";
        string memory network = "orderlyop";
        _test_onchain_vaultManager(env, network);
    }

    function test_onchain_vaultManager_mainnet() external {
        vm.selectFork(mainnetFork);
        string memory env = "mainnet";
        string memory network = "orderlymain";
        _test_onchain_vaultManager(env, network);
    }

    function _test_onchain_vaultManager(string memory env, string memory network) internal {
        LedgerDeployData memory config = getLedgerDeployData(env, network);
        address vaultManagerAddress = config.vaultManager;
        console.log("vaultManagerAddress: ", vaultManagerAddress);
        IVaultManager vaultManager = IVaultManager(vaultManagerAddress);
        // brokerId
        bytes32[] memory allAllowedBroker = vaultManager.getAllAllowedBroker();
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
        bytes32[] memory allAllowedToken = vaultManager.getAllAllowedToken();
        console2.log("allAllowedToken length: ", allAllowedToken.length);
        for (uint256 i = 0; i < allAllowedToken.length; i++) {
            console2.logBytes32(allAllowedToken[i]);
        }
        assertEq(allAllowedToken.length, 1); // only 1 token is set
        assertEq(allAllowedToken[0], TOKEN_0);
        // symbol
        bytes32[] memory allAllowedSymbol = vaultManager.getAllAllowedSymbol();
        console2.log("allAllowedSymbol length: ", allAllowedSymbol.length);
        bool foundPerpBTCUSDC = false;
        bool foundPerpETHUSDC = false;
        bool foundPerpWOOUSDC = false;
        bool foundPerpTIAUSDC = false;
        for (uint256 i = 0; i < allAllowedSymbol.length; i++) {
            console2.logBytes32(allAllowedSymbol[i]);
            if (PERP_BTC_USDC == allAllowedSymbol[i]) {
                foundPerpBTCUSDC = true;
            } else if (PERP_ETH_USDC == allAllowedSymbol[i]) {
                foundPerpETHUSDC = true;
            } else if (PERP_WOO_USDC == allAllowedSymbol[i]) {
                foundPerpWOOUSDC = true;
            } else if (PERP_TIA_USDC == allAllowedSymbol[i]) {
                foundPerpTIAUSDC = true;
            }
        }
        assertGe(allAllowedSymbol.length, 4); // at least 4 symbols is set
        assertTrue(foundPerpBTCUSDC);
        assertTrue(foundPerpETHUSDC);
        assertTrue(foundPerpWOOUSDC);
        assertTrue(foundPerpTIAUSDC);
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../../src/vaultSide/Vault.sol";
import "../../script/utils/ConfigHelper.s.sol";
import "../mock/Blacklistable.sol";
import "../../src/vaultSide/tUSDC.sol";

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

    // configuration for onchain configuration to test withdraw
    string constant INFURA_KEY = "12af7b65cde2493ba17a03686429d857"; // API key used to fork from infura archive node to retrieve the old state to avoid the storage error, should be replaced with your infura API key
    string constant RPC_URL_ARBITRUM = "https://arbitrum-mainnet.infura.io/v3/";
    string constant RPC_URL_ARBITRUMSEPOLIA = "https://arbitrum-sepolia.infura.io/v3/";
    string constant RPC_URL_OP = "https://optimism-mainnet.infura.io/v3/";
    string constant RPC_URL_OPSEPOLIA = "https://optimism-sepolia.infura.io/v3/";
    string constant RPC_URL_POLYGON = "https://polygon-mainnet.infura.io/v3/";
    string constant RPC_URL_MUMBAI = "https://polygon-mumbai.infura.io/v3/";

    address constant USDC_ADDRESS = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d;
    address constant VAULT_ADDRESS = 0x3ac2Ba11Ca2f9f109d50fb1a46d4C23fCadbbef6;
    Vault onchainVault = Vault(VAULT_ADDRESS);
    address constant CC_MANAGER_ADDRESS = 0xCf474548756Eb48A14D08Ca514F728f72a8F629D;
    bytes32 constant WOOFI_RPO_BROKER_ID = 0x6ca2f644ef7bd6d75953318c7f2580014941e753b3c6d54da56b3bf75dd14dfc; // woofi_pro
    bytes32 constant USDC_TOKEN_HASH = 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa; // USDC
    address constant SENDER_ADDRESS = 0xDd3287043493E0a08d2B348397554096728B459c;
    address constant ZERO_ADDRESS = address(0);
    address constant BLACKLISTER = 0xdD332F4beb37166F9ec6093e2C97592FA745A4ab;
    address constant BLACKLISTED_ADDRESS = 0x2bAC7A6771613440989432c9B3B9a45dDd15e657;
    uint128 constant TOKEN_AMOUNT = 10_000_000;
    uint64 constant FEE_AMOUNT = 2_000_000;
    uint64 constant WITHDRAW_NONCE = 123;

    function setUp() public {
        mainnetArbitrumFork = vm.createFork(string.concat(RPC_URL_ARBITRUM, INFURA_KEY));
        mainnetOptimismFork = vm.createFork(string.concat(RPC_URL_OP, INFURA_KEY));
        mainnetPolygonFork = vm.createFork(string.concat(RPC_URL_POLYGON, INFURA_KEY));
        stagingArbitrumFork = vm.createFork(string.concat(RPC_URL_ARBITRUMSEPOLIA, INFURA_KEY));
        stagingOptimismFork = vm.createFork(string.concat(RPC_URL_OPSEPOLIA, INFURA_KEY));
        stagingPolygonFork = vm.createFork(string.concat(RPC_URL_MUMBAI, INFURA_KEY));
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

    function test_onchain_zero_withdraw() public {
        vm.createSelectFork(string.concat(RPC_URL_ARBITRUMSEPOLIA, INFURA_KEY));
        VaultTypes.VaultWithdraw memory zeroWithdrawData = VaultTypes.VaultWithdraw({
            accountId: Utils.calculateAccountId(ZERO_ADDRESS, WOOFI_RPO_BROKER_ID),
            sender: SENDER_ADDRESS,
            receiver: ZERO_ADDRESS,
            brokerHash: WOOFI_RPO_BROKER_ID,
            tokenHash: USDC_TOKEN_HASH,
            tokenAmount: 10_000_000,
            fee: 2_000_000,
            withdrawNonce: 123
        });

        vm.mockCall(address(CC_MANAGER_ADDRESS), abi.encodeWithSelector(IVault.withdraw.selector), abi.encode());

        vm.startPrank(CC_MANAGER_ADDRESS);
        onchainVault.withdraw(zeroWithdrawData);
        vm.stopPrank();
    }

    function testRevert_onchain_blacklisted_withdraw() public {
        Blacklistable usdc = Blacklistable(USDC_ADDRESS);
        uint256 BEFORE_FIXED = 8845399;

        vm.createSelectFork(string.concat(RPC_URL_ARBITRUMSEPOLIA, INFURA_KEY), BEFORE_FIXED);

        vm.startPrank(BLACKLISTER);
        usdc.blacklist(BLACKLISTED_ADDRESS);
        vm.stopPrank();

        VaultTypes.VaultWithdraw memory blacklistedWithdrawData = VaultTypes.VaultWithdraw({
            accountId: Utils.calculateAccountId(BLACKLISTED_ADDRESS, WOOFI_RPO_BROKER_ID),
            sender: SENDER_ADDRESS,
            receiver: BLACKLISTED_ADDRESS,
            brokerHash: WOOFI_RPO_BROKER_ID,
            tokenHash: USDC_TOKEN_HASH,
            tokenAmount: TOKEN_AMOUNT,
            fee: FEE_AMOUNT,
            withdrawNonce: WITHDRAW_NONCE
        });

        vm.mockCall(address(CC_MANAGER_ADDRESS), abi.encodeWithSelector(IVault.withdraw.selector), abi.encode());
        vm.startPrank(CC_MANAGER_ADDRESS);
        vm.expectRevert(bytes("Blacklistable: account is blacklisted"));
        onchainVault.withdraw(blacklistedWithdrawData);
        vm.stopPrank();
    }

    function test_onchain_backlisted_withdraw() public {
        Blacklistable usdc = Blacklistable(USDC_ADDRESS);

        uint256 AFTER_FIXED = 28941996;
        vm.createSelectFork(string.concat(RPC_URL_ARBITRUMSEPOLIA, INFURA_KEY), AFTER_FIXED);

        vm.startPrank(BLACKLISTER);
        usdc.blacklist(BLACKLISTED_ADDRESS);
        vm.stopPrank();

        VaultTypes.VaultWithdraw memory blacklistedWithdrawData = VaultTypes.VaultWithdraw({
            accountId: Utils.calculateAccountId(BLACKLISTED_ADDRESS, WOOFI_RPO_BROKER_ID),
            sender: SENDER_ADDRESS,
            receiver: BLACKLISTED_ADDRESS,
            brokerHash: WOOFI_RPO_BROKER_ID,
            tokenHash: USDC_TOKEN_HASH,
            tokenAmount: TOKEN_AMOUNT,
            fee: FEE_AMOUNT,
            withdrawNonce: WITHDRAW_NONCE
        });

        vm.mockCall(address(CC_MANAGER_ADDRESS), abi.encodeWithSelector(IVault.withdraw.selector), abi.encode());
        uint256 beforeBalance = usdc.balanceOf(VAULT_ADDRESS);
        vm.startPrank(CC_MANAGER_ADDRESS);
        onchainVault.withdraw(blacklistedWithdrawData);
        vm.stopPrank();
        uint256 afterBalance = usdc.balanceOf(VAULT_ADDRESS);
        assertEq(afterBalance, beforeBalance);
    }

    function test_onchain_withdraw_without_blacklist() public {
        TestUSDC usdc = new TestUSDC();
        address MULTISIG = 0xFae9CAF31EeD9f6480262808920dA03eb7f76E7E; // multisig for dev

        uint256 AFTER_FIXED = 28941996;
        vm.createSelectFork(string.concat(RPC_URL_ARBITRUMSEPOLIA, INFURA_KEY), AFTER_FIXED);

        vm.startPrank(MULTISIG);
        onchainVault.changeTokenAddressAndAllow(USDC_TOKEN_HASH, address(usdc));
        usdc.mint(VAULT_ADDRESS, TOKEN_AMOUNT);
        vm.stopPrank();

        VaultTypes.VaultWithdraw memory blacklistedWithdrawData = VaultTypes.VaultWithdraw({
            accountId: Utils.calculateAccountId(BLACKLISTED_ADDRESS, WOOFI_RPO_BROKER_ID),
            sender: SENDER_ADDRESS,
            receiver: BLACKLISTED_ADDRESS,
            brokerHash: WOOFI_RPO_BROKER_ID,
            tokenHash: USDC_TOKEN_HASH,
            tokenAmount: TOKEN_AMOUNT,
            fee: FEE_AMOUNT,
            withdrawNonce: WITHDRAW_NONCE
        });

        vm.mockCall(address(CC_MANAGER_ADDRESS), abi.encodeWithSelector(IVault.withdraw.selector), abi.encode());
        vm.startPrank(CC_MANAGER_ADDRESS);
        onchainVault.withdraw(blacklistedWithdrawData);
        vm.stopPrank();
        assertEq(usdc.balanceOf(VAULT_ADDRESS), FEE_AMOUNT);
        assertEq(usdc.balanceOf(BLACKLISTED_ADDRESS), TOKEN_AMOUNT - FEE_AMOUNT);
    }
}

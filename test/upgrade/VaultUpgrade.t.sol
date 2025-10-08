// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/vaultSide/Vault.sol";
import "../../src/interface/IVault.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

contract VaultUpgradeTest is Test {
    // Base RPC URL for forking
    string constant BASE_RPC_URL = "https://mainnet.base.org";
    
    // Variables to store contract references
    Vault vault;
    ProxyAdmin proxyAdmin;
    address vaultProxyAddress;
    
    // Known addresses on Base
    address constant WETH_ADDRESS = 0x4200000000000000000000000000000000000006;
    
    // Fill this in with the actual Vault proxy address on Base
    address constant VAULT_PROXY_ADDRESS = 0x816f722424B49Cf1275cc86DA9840Fbd5a6167e9;
    
    // Storage variables to check before and after upgrade
    bytes32 initialNativeTokenHash;
    address initialCrossChainManager;
    uint64 initialDepositId;
    bool initialDepositFeeEnabled;
    address initialTokenMessengerContract;
    address initialMessageTransmitterContract;
    address initialProtocolVault;
    
    // Store allowed token addresses and brokers for verification
    bytes32[] initialAllowedTokens;
    bytes32[] initialAllowedBrokers;
    
    // For some specific token and broker, store their allowance status
    address initialTokenAddress;
    bool initialTokenAllowed;
    bool initialBrokerAllowed;
    
    // Store slot values for low-level verification
    mapping(uint256 => bytes32) initialSlotValues;
    
    function setUp() public {
        // Fork the latest block from Base
        vm.createSelectFork(BASE_RPC_URL);
        
        // Use the constant address for the proxy
        vaultProxyAddress = VAULT_PROXY_ADDRESS;
        
        // Get the admin address from the proxy slot
        address adminAddress = getProxyAdmin(vaultProxyAddress);
        proxyAdmin = ProxyAdmin(adminAddress);
        
        // Connect to the existing vault through the proxy
        vault = Vault(vaultProxyAddress);
        
        // Store the initial state for later comparison
        captureInitialState();
        
        // Capture low-level storage values for key slots
        captureStorageSlots(50); // Capture first 50 slots for demonstration
    }
    
    function testUpgradeVault() public {
        // Deploy a new implementation of Vault
        Vault newImplementation = new Vault();
        
        // Store expanded initial state
        bytes32[] memory tokensBeforeUpgrade = vault.getAllAllowedToken();
        bytes32[] memory brokersBeforeUpgrade = vault.getAllAllowedBroker();
        
        // Upgrade the implementation
        vm.startPrank(proxyAdmin.owner());
        proxyAdmin.upgrade(ITransparentUpgradeableProxy(payable(vaultProxyAddress)), address(newImplementation));
        vm.stopPrank();
        
        // Verify the implementation address changed
        address newImplementationAddr = proxyAdmin.getProxyImplementation(ITransparentUpgradeableProxy(payable(vaultProxyAddress)));
        assertEq(newImplementationAddr, address(newImplementation), "Implementation address should be updated");
        
        // Verify slots directly to ensure storage layout hasn't changed
        verifyStorageSlots(50); // Check first 50 slots
        
        // Capture the state after the upgrade
        (
            address afterCrossChainManager,
            uint64 afterDepositId,
            bool afterDepositFeeEnabled,
            address afterTokenMessengerContract,
            address afterMessageTransmitterContract,
            address afterProtocolVault
        ) = captureCurrentState();

        
        bytes32[] memory rebalanceEnableTokensAfter = vault.getAllRebalanceEnableToken();
        console.log("rebalanceEnableTokensAfter: ");
        for (uint i = 0; i < rebalanceEnableTokensAfter.length; i++) {
            console.logBytes32(rebalanceEnableTokensAfter[i]);
        }

        // Verify the core storage values are preserved
        assertEq(initialCrossChainManager, afterCrossChainManager, "Cross chain manager should not change");
        assertEq(initialDepositId, afterDepositId, "Deposit ID should not change");
        assertEq(initialDepositFeeEnabled, afterDepositFeeEnabled, "Deposit fee enabled should not change");
        assertEq(initialTokenMessengerContract, afterTokenMessengerContract, "Token messenger contract should not change");
        assertEq(initialMessageTransmitterContract, afterMessageTransmitterContract, "Message transmitter contract should not change");
        assertEq(initialProtocolVault, afterProtocolVault, "Protocol vault should not change");
        
        // Verify collections (tokens and brokers)
        bytes32[] memory tokensAfterUpgrade = vault.getAllAllowedToken();
        bytes32[] memory brokersAfterUpgrade = vault.getAllAllowedBroker();
        
        assertEq(tokensBeforeUpgrade.length, tokensAfterUpgrade.length, "Number of allowed tokens should not change");
        assertEq(brokersBeforeUpgrade.length, brokersAfterUpgrade.length, "Number of allowed brokers should not change");
        
        // Verify the same set of tokens and brokers are still allowed
        for (uint i = 0; i < tokensBeforeUpgrade.length; i++) {
            bool foundMatch = false;
            for (uint j = 0; j < tokensAfterUpgrade.length; j++) {
                if (tokensBeforeUpgrade[i] == tokensAfterUpgrade[j]) {
                    foundMatch = true;
                    break;
                }
            }
            assertTrue(foundMatch, "Token should still be in allowed list after upgrade");
        }
        
        for (uint i = 0; i < brokersBeforeUpgrade.length; i++) {
            bool foundMatch = false;
            for (uint j = 0; j < brokersAfterUpgrade.length; j++) {
                if (brokersBeforeUpgrade[i] == brokersAfterUpgrade[j]) {
                    foundMatch = true;
                    break;
                }
            }
            assertTrue(foundMatch, "Broker should still be in allowed list after upgrade");
        }
        
        // Check specific token and broker allowances
        if (initialTokenAddress != address(0)) {
            bytes32 tokenHash = getTokenHashForAddress(initialTokenAddress);
            bool tokenAllowedAfter = vault.getAllowedToken(tokenHash) != address(0);
            assertEq(initialTokenAllowed, tokenAllowedAfter, "Token allowance status should not change");
        }
        
        if (initialAllowedBrokers.length > 0) {
            bytes32 brokerHash = initialAllowedBrokers[0];
            bool brokerAllowedAfter = vault.getAllowedBroker(brokerHash);
            assertEq(initialBrokerAllowed, brokerAllowedAfter, "Broker allowance status should not change");
        }
        
    }
    
    // Capture storage slot values for later verification
    function captureStorageSlots(uint256 numSlots) internal {
        for (uint256 i = 0; i < numSlots; i++) {
            bytes32 value = getStorageAt(vaultProxyAddress, i);
            initialSlotValues[i] = value;
            // Log some of the initial values for debugging
            if (i < 10) {
                console.log("Slot", i, ":", uint256(value));
            }
        }
    }
    
    // Verify storage slots match after upgrade
    function verifyStorageSlots(uint256 numSlots) internal {
        bool allMatch = true;
        for (uint256 i = 0; i < numSlots; i++) {
            bytes32 currentValue = getStorageAt(vaultProxyAddress, i);
            bytes32 originalValue = initialSlotValues[i];
            
            // Skip the implementation slot which has changed
            bytes32 implSlot = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
            bytes32 adminSlot = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
            
            if (i == uint256(implSlot) || i == uint256(adminSlot)) {
                continue;
            }
            
            if (currentValue != originalValue) {
                console.log("Slot mismatch at", i);
                console.log("Original:", uint256(originalValue));
                console.log("Current:", uint256(currentValue));
                allMatch = false;
            }
        }
        assertTrue(allMatch, "All storage slots should match after upgrade");
    }
    
    // Helper to read contract storage at a specific slot
    function getStorageAt(address contractAddr, uint256 slot) internal view returns (bytes32) {
        return vm.load(contractAddr, bytes32(slot));
    }
    
    function captureInitialState() internal {
        (
            initialCrossChainManager,
            initialDepositId,
            initialDepositFeeEnabled,
            initialTokenMessengerContract,
            initialMessageTransmitterContract,
            initialProtocolVault
        ) = captureCurrentState();
        
        // Get allowed tokens and brokers
        initialAllowedTokens = vault.getAllAllowedToken();
        initialAllowedBrokers = vault.getAllAllowedBroker();
        
        // Store status of a specific token and broker if they exist
        if (initialAllowedTokens.length > 0) {
            bytes32 tokenHash = initialAllowedTokens[0];
            initialTokenAddress = vault.getAllowedToken(tokenHash);
            initialTokenAllowed = initialTokenAddress != address(0);
        }
        
        if (initialAllowedBrokers.length > 0) {
            bytes32 brokerHash = initialAllowedBrokers[0];
            initialBrokerAllowed = vault.getAllowedBroker(brokerHash);
        }
    }
    
    function captureCurrentState() internal view returns (
        address crossChainManager,
        uint64 depositId,
        bool depositFeeEnabled,
        address tokenMessengerContract,
        address messageTransmitterContract,
        address protocolVault
    ) {
        crossChainManager = vault.crossChainManagerAddress();
        depositId = vault.depositId();
        depositFeeEnabled = vault.depositFeeEnabled();
        tokenMessengerContract = vault.tokenMessengerContract();
        messageTransmitterContract = vault.messageTransmitterContract();
        protocolVault = address(vault.protocolVault());
    }
    
    // Helper function to get the admin address of a proxy
    function getProxyAdmin(address proxy) internal view returns (address) {
        // Admin slot for TransparentUpgradeableProxy
        bytes32 slot = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
        return address(uint160(uint256(vm.load(proxy, slot))));
    }
    
    // Helper to find token hash for a token address (usually we'd have this from the original deployment)
    function getTokenHashForAddress(address tokenAddr) internal view returns (bytes32) {
        bytes32[] memory tokens = vault.getAllAllowedToken();
        for (uint i = 0; i < tokens.length; i++) {
            if (vault.getAllowedToken(tokens[i]) == tokenAddr) {
                return tokens[i];
            }
        }
        return bytes32(0);
    }
    
    // Test deposit functionality after upgrade (optional - requires setup)
    function testDepositAfterUpgrade() public {
        // Skip this test if conditions aren't right
        if (initialAllowedTokens.length == 0 || initialAllowedBrokers.length == 0) {
            return;
        }
        
        // Upgrade the vault first
        Vault newImplementation = new Vault();
        vm.prank(proxyAdmin.owner());
        proxyAdmin.upgrade(ITransparentUpgradeableProxy(payable(vaultProxyAddress)), address(newImplementation));
        
        // Find a suitable token for testing
        bytes32 tokenHash = initialAllowedTokens[0];
        address tokenAddress = vault.getAllowedToken(tokenHash);
        if (tokenAddress == address(0)) return; // Skip if no valid token
        
        // In a real test, you would:
        // 1. Create a test account
        // 2. Get some of the token
        // 3. Approve the vault to spend the token
        // 4. Create a deposit struct
        // 5. Call deposit and verify it succeeds
        
        // But this is simplified for illustration:
        console.log("After upgrade, vault recognizes token:", tokenAddress);
        console.log("Token hash:", uint256(tokenHash));
    }
    
    // Test that the new implementation's features work
    function testNewFeaturesAfterUpgrade() public {
        // Deploy the new implementation with any new features
        Vault newImplementation = new Vault();
        
        // Upgrade to it
        vm.prank(proxyAdmin.owner());
        proxyAdmin.upgrade(ITransparentUpgradeableProxy(payable(vaultProxyAddress)), address(newImplementation));
        
        // Here you would test any new functions or features added in the new implementation
        // For example, if there's a new configuration method
    }
    
}
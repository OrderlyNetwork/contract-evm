// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../src/VaultManager.sol";
import "../src/library/types/RebalanceTypes.sol";
import "../src/interface/error/IError.sol";
import "../src/oz5Revised/IAccessControlRevised.sol";

contract VaultManagerAccessControlTest is Test {
    // Components
    ProxyAdmin admin;
    VaultManager vaultManager;
    TransparentUpgradeableProxy vaultManagerProxy;
    
    // Test accounts
    address owner;
    address alice;
    address bob;
    address charlie;
    address ledger;
    address symbolManager;
    address brokerManager;
    
    // Test constants
    bytes32 constant TEST_TOKEN_HASH = keccak256("TEST_TOKEN");
    bytes32 constant TEST_SYMBOL_HASH = keccak256("TEST_SYMBOL");
    bytes32 constant TEST_BROKER_HASH = keccak256("TEST_BROKER");
    uint256 constant TEST_CHAIN_ID = 1;
    uint128 constant TEST_AMOUNT = 1000;
    
    // Role constants from VaultManager
    bytes32 constant SYMBOL_MANAGER_ROLE = keccak256("ORDERLY_MANAGER_SYMBOL_MANAGER_ROLE");
    bytes32 constant BROKER_MANAGER_ROLE = keccak256("ORDERLY_MANAGER_BROKER_MANAGER_ROLE");
    
    function setUp() public {
        // Setup test accounts
        owner = address(this); // Test contract is the owner
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        ledger = makeAddr("ledger");
        symbolManager = makeAddr("symbolManager");
        brokerManager = makeAddr("brokerManager");
        
        // Deploy VaultManager with proxy
        admin = new ProxyAdmin();
        VaultManager vaultManagerImpl = new VaultManager();
        vaultManagerProxy = new TransparentUpgradeableProxy(
            address(vaultManagerImpl), 
            address(admin), 
            ""
        );
        vaultManager = VaultManager(address(vaultManagerProxy));
        
        // Initialize VaultManager
        vaultManager.initialize();
        
        // Set ledger address (owner can do this)
        vaultManager.setLedgerAddress(ledger);
    }
    
    // ==================== OWNER-ONLY FUNCTIONS ====================
    
    function test_ownerCanSetAllowedToken() public {
        // Owner should be able to set allowed token
        vaultManager.setAllowedToken(TEST_TOKEN_HASH, true);
        assertTrue(vaultManager.getAllowedToken(TEST_TOKEN_HASH));
        
        // Owner should be able to unset allowed token
        vaultManager.setAllowedToken(TEST_TOKEN_HASH, false);
        assertFalse(vaultManager.getAllowedToken(TEST_TOKEN_HASH));
    }
    
    function test_nonOwnerCannotSetAllowedToken() public {
        // Alice (non-owner) should not be able to set allowed token
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        vaultManager.setAllowedToken(TEST_TOKEN_HASH, true);
    }
    
    function test_ownerCanSetAllowedChainToken() public {
        // First set the token as allowed
        vaultManager.setAllowedToken(TEST_TOKEN_HASH, true);
        
        // Owner should be able to set allowed chain token
        vaultManager.setAllowedChainToken(TEST_TOKEN_HASH, TEST_CHAIN_ID, true);
        assertTrue(vaultManager.getAllowedChainToken(TEST_TOKEN_HASH, TEST_CHAIN_ID));
    }
    
    function test_nonOwnerCannotSetAllowedChainToken() public {
        vm.prank(alice);
        // TODO: change to AccessControlUnauthorizedAccount
        vm.expectRevert("Ownable: caller is not the owner");
        vaultManager.setAllowedChainToken(TEST_TOKEN_HASH, TEST_CHAIN_ID, true);
    }
    
    function test_ownerCanSetMaxWithdrawFee() public {
        vaultManager.setMaxWithdrawFee(TEST_TOKEN_HASH, TEST_AMOUNT);
        assertEq(vaultManager.getMaxWithdrawFee(TEST_TOKEN_HASH), TEST_AMOUNT);
    }
    
    function test_nonOwnerCannotSetMaxWithdrawFee() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IAccessControlRevised.AccessControlUnauthorizedAccount.selector, alice, SYMBOL_MANAGER_ROLE));
        vaultManager.setMaxWithdrawFee(TEST_TOKEN_HASH, TEST_AMOUNT);
    }
    
    function test_ownerCanSetChain2cctpMeta() public {
        address testVaultAddress = makeAddr("testVault");
        vaultManager.setChain2cctpMeta(TEST_CHAIN_ID, 1, testVaultAddress);
        
        assertEq(vaultManager.chain2cctpDomain(TEST_CHAIN_ID), 1);
        assertEq(vaultManager.chain2VaultAddress(TEST_CHAIN_ID), testVaultAddress);
    }
    
    function test_nonOwnerCannotSetChain2cctpMeta() public {
        address testVaultAddress = makeAddr("testVault");
        
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        vaultManager.setChain2cctpMeta(TEST_CHAIN_ID, 1, testVaultAddress);
    }
    
    function test_ownerCanSetProtocolVaultAddress() public {
        address protocolVault = makeAddr("protocolVault");
        vaultManager.setProtocolVaultAddress(protocolVault);
        assertEq(vaultManager.getProtocolVaultAddress(), protocolVault);
    }
    
    function test_nonOwnerCannotSetProtocolVaultAddress() public {
        address protocolVault = makeAddr("protocolVault");
        
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        vaultManager.setProtocolVaultAddress(protocolVault);
    }
    
    function test_setProtocolVaultAddressRevertsOnZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IError.AddressZero.selector));
        vaultManager.setProtocolVaultAddress(address(0));
    }
    
    // ==================== ROLE-BASED ACCESS CONTROL ====================
    
    function test_ownerCanGrantAndRevokeRoles() public {
        // Owner should be able to grant roles
        vaultManager.grantRole(SYMBOL_MANAGER_ROLE, symbolManager);
        assertTrue(vaultManager.hasRole(SYMBOL_MANAGER_ROLE, symbolManager));
        
        vaultManager.grantRole(BROKER_MANAGER_ROLE, brokerManager);
        assertTrue(vaultManager.hasRole(BROKER_MANAGER_ROLE, brokerManager));
        
        // Owner should be able to revoke roles
        vaultManager.revokeRole(SYMBOL_MANAGER_ROLE, symbolManager);
        assertFalse(vaultManager.hasRole(SYMBOL_MANAGER_ROLE, symbolManager));
        
        vaultManager.revokeRole(BROKER_MANAGER_ROLE, brokerManager);
        assertFalse(vaultManager.hasRole(BROKER_MANAGER_ROLE, brokerManager));
    }
    
    function test_nonOwnerCannotGrantRoles() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        vaultManager.grantRole(SYMBOL_MANAGER_ROLE, symbolManager);
    }
    
    function test_nonOwnerCannotRevokeRoles() public {
        // First grant role as owner
        vaultManager.grantRole(SYMBOL_MANAGER_ROLE, symbolManager);
        
        // Alice should not be able to revoke
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        vaultManager.revokeRole(SYMBOL_MANAGER_ROLE, symbolManager);
    }
    
    // ==================== SYMBOL MANAGER ROLE ====================
    
    function test_symbolManagerCanSetAllowedSymbol() public {
        // Grant role to symbolManager
        vaultManager.grantRole(SYMBOL_MANAGER_ROLE, symbolManager);
        
        // Symbol manager should be able to set allowed symbol
        vm.prank(symbolManager);
        vaultManager.setAllowedSymbol(TEST_SYMBOL_HASH, true);
        assertTrue(vaultManager.getAllowedSymbol(TEST_SYMBOL_HASH));
    }
    
    function test_ownerCanAlsoSetAllowedSymbol() public {
        // Owner should also be able to set allowed symbol (onlyOwnerOrRole modifier)
        vaultManager.setAllowedSymbol(TEST_SYMBOL_HASH, true);
        assertTrue(vaultManager.getAllowedSymbol(TEST_SYMBOL_HASH));
    }
    
    function test_nonSymbolManagerCannotSetAllowedSymbol() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlRevised.AccessControlUnauthorizedAccount.selector, 
            alice, 
            SYMBOL_MANAGER_ROLE
        ));
        vaultManager.setAllowedSymbol(TEST_SYMBOL_HASH, true);
    }
    
    // ==================== BROKER MANAGER ROLE ====================
    
    function test_brokerManagerCanSetAllowedBroker() public {
        // Grant role to brokerManager
        vaultManager.grantRole(BROKER_MANAGER_ROLE, brokerManager);
        
        // Broker manager should be able to set allowed broker
        vm.prank(brokerManager);
        vaultManager.setAllowedBroker(TEST_BROKER_HASH, true);
        assertTrue(vaultManager.getAllowedBroker(TEST_BROKER_HASH));
    }
    
    function test_ownerCanAlsoSetAllowedBroker() public {
        // Owner should also be able to set allowed broker (onlyOwnerOrRole modifier)
        vaultManager.setAllowedBroker(TEST_BROKER_HASH, true);
        assertTrue(vaultManager.getAllowedBroker(TEST_BROKER_HASH));
    }
    
    function test_nonBrokerManagerCannotSetAllowedBroker() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlRevised.AccessControlUnauthorizedAccount.selector, 
            alice, 
            BROKER_MANAGER_ROLE
        ));
        vaultManager.setAllowedBroker(TEST_BROKER_HASH, true);
    }
    
    // ==================== LEDGER-ONLY FUNCTIONS ====================
    
    function test_ledgerCanAddBalance() public {
        vm.prank(ledger);
        vaultManager.addBalance(TEST_TOKEN_HASH, TEST_CHAIN_ID, TEST_AMOUNT);
        assertEq(vaultManager.getBalance(TEST_TOKEN_HASH, TEST_CHAIN_ID), TEST_AMOUNT);
    }
    
    function test_nonLedgerCannotAddBalance() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IError.OnlyLedgerCanCall.selector));
        vaultManager.addBalance(TEST_TOKEN_HASH, TEST_CHAIN_ID, TEST_AMOUNT);
    }
    
    function test_ledgerCanSubBalance() public {
        // First add some balance
        vm.prank(ledger);
        vaultManager.addBalance(TEST_TOKEN_HASH, TEST_CHAIN_ID, TEST_AMOUNT);
        
        // Then subtract
        vm.prank(ledger);
        vaultManager.subBalance(TEST_TOKEN_HASH, TEST_CHAIN_ID, TEST_AMOUNT / 2);
        assertEq(vaultManager.getBalance(TEST_TOKEN_HASH, TEST_CHAIN_ID), TEST_AMOUNT / 2);
    }
    
    function test_nonLedgerCannotSubBalance() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IError.OnlyLedgerCanCall.selector));
        vaultManager.subBalance(TEST_TOKEN_HASH, TEST_CHAIN_ID, TEST_AMOUNT);
    }
    
    function test_ledgerCanFrozenBalance() public {
        // First add some balance
        vm.prank(ledger);
        vaultManager.addBalance(TEST_TOKEN_HASH, TEST_CHAIN_ID, TEST_AMOUNT);
        
        // Then freeze some
        vm.prank(ledger);
        vaultManager.frozenBalance(TEST_TOKEN_HASH, TEST_CHAIN_ID, TEST_AMOUNT / 2);
        
        assertEq(vaultManager.getBalance(TEST_TOKEN_HASH, TEST_CHAIN_ID), TEST_AMOUNT / 2);
        assertEq(vaultManager.getFrozenBalance(TEST_TOKEN_HASH, TEST_CHAIN_ID), TEST_AMOUNT / 2);
    }
    
    function test_nonLedgerCannotFrozenBalance() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IError.OnlyLedgerCanCall.selector));
        vaultManager.frozenBalance(TEST_TOKEN_HASH, TEST_CHAIN_ID, TEST_AMOUNT);
    }
    
    function test_ledgerCanUnfrozenBalance() public {
        // Setup: add and freeze balance
        vm.startPrank(ledger);
        vaultManager.addBalance(TEST_TOKEN_HASH, TEST_CHAIN_ID, TEST_AMOUNT);
        vaultManager.frozenBalance(TEST_TOKEN_HASH, TEST_CHAIN_ID, TEST_AMOUNT / 2);
        
        // Unfreeze
        vaultManager.unfrozenBalance(TEST_TOKEN_HASH, TEST_CHAIN_ID, TEST_AMOUNT / 4);
        vm.stopPrank();
        
        assertEq(vaultManager.getBalance(TEST_TOKEN_HASH, TEST_CHAIN_ID), TEST_AMOUNT * 3 / 4);
        assertEq(vaultManager.getFrozenBalance(TEST_TOKEN_HASH, TEST_CHAIN_ID), TEST_AMOUNT / 4);
    }
    
    function test_nonLedgerCannotUnfrozenBalance() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IError.OnlyLedgerCanCall.selector));
        vaultManager.unfrozenBalance(TEST_TOKEN_HASH, TEST_CHAIN_ID, TEST_AMOUNT);
    }
    
    function test_ledgerCanFinishFrozenBalance() public {
        // Setup: add and freeze balance
        vm.startPrank(ledger);
        vaultManager.addBalance(TEST_TOKEN_HASH, TEST_CHAIN_ID, TEST_AMOUNT);
        vaultManager.frozenBalance(TEST_TOKEN_HASH, TEST_CHAIN_ID, TEST_AMOUNT / 2);
        
        // Finish frozen (remove from frozen without adding back to balance)
        vaultManager.finishFrozenBalance(TEST_TOKEN_HASH, TEST_CHAIN_ID, TEST_AMOUNT / 4);
        vm.stopPrank();
        
        assertEq(vaultManager.getBalance(TEST_TOKEN_HASH, TEST_CHAIN_ID), TEST_AMOUNT / 2);
        assertEq(vaultManager.getFrozenBalance(TEST_TOKEN_HASH, TEST_CHAIN_ID), TEST_AMOUNT / 4);
    }
    
    function test_nonLedgerCannotFinishFrozenBalance() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IError.OnlyLedgerCanCall.selector));
        vaultManager.finishFrozenBalance(TEST_TOKEN_HASH, TEST_CHAIN_ID, TEST_AMOUNT);
    }
    
    // ==================== REBALANCE FUNCTIONS (LEDGER-ONLY) ====================
    
    function test_ledgerCanExecuteRebalanceBurn() public {
        // Setup: set allowed tokens and chain
        vaultManager.setAllowedToken(TEST_TOKEN_HASH, true);
        vaultManager.setAllowedChainToken(TEST_TOKEN_HASH, 1, true); // burn chain
        vaultManager.setAllowedChainToken(TEST_TOKEN_HASH, 2, true); // mint chain
        
        // Set chain metadata
        address vaultAddress = makeAddr("vault");
        vaultManager.setChain2cctpMeta(2, 1, vaultAddress); // mint chain
        
        // Add balance to burn from
        vm.prank(ledger);
        vaultManager.addBalance(TEST_TOKEN_HASH, 1, TEST_AMOUNT);
        
        // Execute rebalance burn
        RebalanceTypes.RebalanceBurnUploadData memory data = RebalanceTypes.RebalanceBurnUploadData({
            r: bytes32(0),
            s: bytes32(0),
            v: 0,
            rebalanceId: 1,
            amount: TEST_AMOUNT / 2,
            tokenHash: TEST_TOKEN_HASH,
            burnChainId: 1,
            mintChainId: 2
        });
        
        vm.prank(ledger);
        (uint32 dstDomain, address dstVaultAddress) = vaultManager.executeRebalanceBurn(data);
        
        assertEq(dstDomain, 1);
        assertEq(dstVaultAddress, vaultAddress);
    }
    
    function test_nonLedgerCannotExecuteRebalanceBurn() public {
        RebalanceTypes.RebalanceBurnUploadData memory data = RebalanceTypes.RebalanceBurnUploadData({
            r: bytes32(0),
            s: bytes32(0),
            v: 0,
            rebalanceId: 1,
            amount: TEST_AMOUNT,
            tokenHash: TEST_TOKEN_HASH,
            burnChainId: 1,
            mintChainId: 2
        });
        
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IError.OnlyLedgerCanCall.selector));
        vaultManager.executeRebalanceBurn(data);
    }
    
    function test_ledgerCanRebalanceBurnFinish() public {
        RebalanceTypes.RebalanceBurnCCFinishData memory data = RebalanceTypes.RebalanceBurnCCFinishData({
            success: true,
            rebalanceId: 1,
            amount: TEST_AMOUNT,
            tokenHash: TEST_TOKEN_HASH,
            burnChainId: 1,
            mintChainId: 2
        });
        
        vm.prank(ledger);
        // This will revert because rebalance wasn't started, but we're testing access control
        vm.expectRevert(abi.encodeWithSelector(
            IError.RebalanceIdNotMatch.selector, 
            1, 
            0
        ));
        vaultManager.rebalanceBurnFinish(data);
    }
    
    function test_nonLedgerCannotRebalanceBurnFinish() public {
        RebalanceTypes.RebalanceBurnCCFinishData memory data = RebalanceTypes.RebalanceBurnCCFinishData({
            success: true,
            rebalanceId: 1,
            amount: TEST_AMOUNT,
            tokenHash: TEST_TOKEN_HASH,
            burnChainId: 1,
            mintChainId: 2
        });
        
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IError.OnlyLedgerCanCall.selector));
        vaultManager.rebalanceBurnFinish(data);
    }
    
    function test_ledgerCanExecuteRebalanceMint() public {
        RebalanceTypes.RebalanceMintUploadData memory data = RebalanceTypes.RebalanceMintUploadData({
            r: bytes32(0),
            s: bytes32(0),
            v: 0,
            rebalanceId: 1,
            amount: TEST_AMOUNT,
            tokenHash: TEST_TOKEN_HASH,
            burnChainId: 1,
            mintChainId: 2,
            messageBytes: hex"",
            messageSignature: hex""
        });
        
        vm.prank(ledger);
        // This will revert because burn wasn't executed first, but we're testing access control
        vm.expectRevert(abi.encodeWithSelector(IError.RebalanceMintUnexpected.selector));
        vaultManager.executeRebalanceMint(data);
    }
    
    function test_nonLedgerCannotExecuteRebalanceMint() public {
        RebalanceTypes.RebalanceMintUploadData memory data = RebalanceTypes.RebalanceMintUploadData({
            r: bytes32(0),
            s: bytes32(0),
            v: 0,
            rebalanceId: 1,
            amount: TEST_AMOUNT,
            tokenHash: TEST_TOKEN_HASH,
            burnChainId: 1,
            mintChainId: 2,
            messageBytes: hex"",
            messageSignature: hex""
        });
        
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IError.OnlyLedgerCanCall.selector));
        vaultManager.executeRebalanceMint(data);
    }
    
    function test_ledgerCanRebalanceMintFinish() public {
        RebalanceTypes.RebalanceMintCCFinishData memory data = RebalanceTypes.RebalanceMintCCFinishData({
            success: true,
            rebalanceId: 1,
            amount: TEST_AMOUNT,
            tokenHash: TEST_TOKEN_HASH,
            burnChainId: 1,
            mintChainId: 2
        });
        
        vm.prank(ledger);
        // This will revert because rebalance wasn't started, but we're testing access control
        vm.expectRevert(abi.encodeWithSelector(
            IError.RebalanceIdNotMatch.selector, 
            1, 
            0
        ));
        vaultManager.rebalanceMintFinish(data);
    }
    
    function test_nonLedgerCannotRebalanceMintFinish() public {
        RebalanceTypes.RebalanceMintCCFinishData memory data = RebalanceTypes.RebalanceMintCCFinishData({
            success: true,
            rebalanceId: 1,
            amount: TEST_AMOUNT,
            tokenHash: TEST_TOKEN_HASH,
            burnChainId: 1,
            mintChainId: 2
        });
        
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IError.OnlyLedgerCanCall.selector));
        vaultManager.rebalanceMintFinish(data);
    }
    
    // ==================== VIEW FUNCTIONS (NO ACCESS CONTROL) ====================
    
    function test_anyoneCanCallViewFunctions() public {
        // These functions should be callable by anyone
        vm.prank(alice);
        vaultManager.getBalance(TEST_TOKEN_HASH, TEST_CHAIN_ID);
        vaultManager.getFrozenBalance(TEST_TOKEN_HASH, TEST_CHAIN_ID);
        vaultManager.getAllowedToken(TEST_TOKEN_HASH);
        vaultManager.getAllowedBroker(TEST_BROKER_HASH);
        vaultManager.getAllowedSymbol(TEST_SYMBOL_HASH);
        vaultManager.getAllowedChainToken(TEST_TOKEN_HASH, TEST_CHAIN_ID);
        vaultManager.getMaxWithdrawFee(TEST_TOKEN_HASH);
        vaultManager.getAllAllowedToken();
        vaultManager.getAllAllowedBroker();
        vaultManager.getAllAllowedSymbol();
        vaultManager.getRebalanceStatus(1);
        vaultManager.getProtocolVaultAddress();
        vaultManager.hasRole(SYMBOL_MANAGER_ROLE, alice);
        vaultManager.getRoleAdmin(SYMBOL_MANAGER_ROLE);
    }
    
    // ==================== EDGE CASES ====================
    
    function test_setAllowedTokenEnumerableSetError() public {
        // First set to true
        vaultManager.setAllowedToken(TEST_TOKEN_HASH, true);
        
        // Setting to true again should revert with EnumerableSetError
        vm.expectRevert(abi.encodeWithSelector(IError.EnumerableSetError.selector));
        vaultManager.setAllowedToken(TEST_TOKEN_HASH, true);
    }
    
    function test_setAllowedSymbolEnumerableSetError() public {
        vaultManager.grantRole(SYMBOL_MANAGER_ROLE, symbolManager);
        
        vm.startPrank(symbolManager);
        vaultManager.setAllowedSymbol(TEST_SYMBOL_HASH, true);
        
        // Setting to true again should revert with EnumerableSetError
        vm.expectRevert(abi.encodeWithSelector(IError.EnumerableSetError.selector));
        vaultManager.setAllowedSymbol(TEST_SYMBOL_HASH, true);
        vm.stopPrank();
    }
    
    function test_setAllowedBrokerEnumerableSetError() public {
        vaultManager.grantRole(BROKER_MANAGER_ROLE, brokerManager);
        
        vm.startPrank(brokerManager);
        vaultManager.setAllowedBroker(TEST_BROKER_HASH, true);
        
        // Setting to true again should revert with EnumerableSetError
        vm.expectRevert(abi.encodeWithSelector(IError.EnumerableSetError.selector));
        vaultManager.setAllowedBroker(TEST_BROKER_HASH, true);
        vm.stopPrank();
    }
    
    function test_roleBasedAccessWithMultipleRoleHolders() public {
        address symbolManager2 = makeAddr("symbolManager2");
        address brokerManager2 = makeAddr("brokerManager2");
        
        // Grant roles to multiple addresses
        vaultManager.grantRole(SYMBOL_MANAGER_ROLE, symbolManager);
        vaultManager.grantRole(SYMBOL_MANAGER_ROLE, symbolManager2);
        vaultManager.grantRole(BROKER_MANAGER_ROLE, brokerManager);
        vaultManager.grantRole(BROKER_MANAGER_ROLE, brokerManager2);
        
        // Both should be able to manage their respective domains
        vm.prank(symbolManager);
        vaultManager.setAllowedSymbol(keccak256("SYMBOL1"), true);
        
        vm.prank(symbolManager2);
        vaultManager.setAllowedSymbol(keccak256("SYMBOL2"), true);
        
        vm.prank(brokerManager);
        vaultManager.setAllowedBroker(keccak256("BROKER1"), true);
        
        vm.prank(brokerManager2);
        vaultManager.setAllowedBroker(keccak256("BROKER2"), true);
        
        assertTrue(vaultManager.getAllowedSymbol(keccak256("SYMBOL1")));
        assertTrue(vaultManager.getAllowedSymbol(keccak256("SYMBOL2")));
        assertTrue(vaultManager.getAllowedBroker(keccak256("BROKER1")));
        assertTrue(vaultManager.getAllowedBroker(keccak256("BROKER2")));
    }
} 
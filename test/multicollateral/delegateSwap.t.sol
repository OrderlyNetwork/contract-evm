// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/vaultSide/Vault.sol";
import "../mock/VaultCrossChainManagerMock.sol";
import "../mock/ERC20Mock.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../src/library/SwapSignature.sol";
import "./OdosSwapRouterMock.sol";
import "forge-std/console.sol";

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

contract DelegateSwapTest is Test {
    // Constants
    uint256 constant SWAP_AMOUNT = 1 ether;
    uint256 constant PRIVATE_KEY = 0xA11CE; // A test private key for signing
    
    // Components
    ProxyAdmin admin;
    VaultCrossChainManagerMock vaultCrossChainManager;
    Vault vault;
    TransparentUpgradeableProxy vaultProxy;
    OdosSwapRouterMock odosRouter;
    address swapOperator;
    address swapSigner;
    
    // Token related
    ERC20Mock usdc;
    bytes32 constant ETH_HASH = keccak256(abi.encodePacked("ETH"));
    bytes32 constant USDC_HASH = keccak256(abi.encodePacked("USDC"));

    function setUp() public {
        // Deploy components
        admin = new ProxyAdmin();
        IVault vaultImpl = new Vault();
        vaultProxy = new TransparentUpgradeableProxy(address(vaultImpl), address(admin), "");
        vault = Vault(address(vaultProxy));
        vault.initialize();
        
        // Setup cross chain manager
        vaultCrossChainManager = new VaultCrossChainManagerMock();
        vault.setCrossChainManager(address(vaultCrossChainManager));
        
        // Deploy Odos Router Mock
        odosRouter = new OdosSwapRouterMock();
        
        // Setup swap operator and signer
        swapOperator = address(0xCAFE);
        swapSigner = vm.addr(PRIVATE_KEY);
        
        // Configure vault
        vault.setSwapOperator(swapOperator);
        vault.setSwapSigner(swapSigner);
        vault.setNativeTokenHash(ETH_HASH);
        
        // Create and configure USDC mock
        usdc = new ERC20Mock("USD Coin", "USDC", 6);
        vault.changeTokenAddressAndAllow(USDC_HASH, address(usdc));
        vault.setAllowedToken(ETH_HASH, true);
        
        // Fund vault with ETH
        vm.deal(address(vault), SWAP_AMOUNT * 2);
        
        // Fund vault with USDC
        usdc.mint(address(vault), 1000000 * 10**6); // 1M USDC
    }

    // Test delegateSwap with ETH
    function test_delegateSwapETH() public {
        bytes memory swapCalldata = abi.encodeWithSelector(
            OdosSwapRouterMock.swapCompact.selector
        );
        
        VaultTypes.DelegateSwap memory swapData = VaultTypes.DelegateSwap({
            tradeId: bytes32(0), // Current nonce in the vault
            chainId: block.chainid,
            inTokenHash: ETH_HASH,
            inTokenAmount: SWAP_AMOUNT,
            to: address(odosRouter),
            value: SWAP_AMOUNT, // ETH value sent
            swapCalldata: swapCalldata,
            r: bytes32(0),
            s: bytes32(0),
            v: uint8(0)
        });
        
        // Sign the swap data
        (uint8 v, bytes32 r, bytes32 s) = signSwapData(swapData, PRIVATE_KEY);
        swapData.r = r;
        swapData.s = s;
        swapData.v = v;
        
        // Record initial balances
        uint256 initialVaultETH = address(vault).balance;
        uint256 initialRouterETH = address(odosRouter).balance;
        
        // Execute the swap as the operator
        vm.prank(swapOperator);
        vault.delegateSwap(swapData);
        
        // Verify ETH was transferred from vault to router
        assertEq(address(vault).balance, initialVaultETH - SWAP_AMOUNT, "Vault ETH balance should decrease");
        assertEq(address(odosRouter).balance, initialRouterETH + SWAP_AMOUNT, "Router ETH balance should increase");
    }
    
    // Test delegateSwap with ERC20 token (USDC)
    function test_delegateSwapERC20() public {
        // Create swap data for USDC
        bytes memory swapCalldata = abi.encodeWithSelector(
            OdosSwapRouterMock.swapCompact.selector
        );
        
        uint256 usdcAmount = 1000 * 10**6; // 1000 USDC
        
        VaultTypes.DelegateSwap memory swapData = VaultTypes.DelegateSwap({
            tradeId: bytes32(uint256(0x01)),
            chainId: block.chainid,
            inTokenHash: USDC_HASH,
            inTokenAmount: usdcAmount,
            to: address(odosRouter),
            value: 0, // No ETH being sent
            swapCalldata: swapCalldata,
            r: bytes32(0),
            s: bytes32(0),
            v: uint8(0)
        });
        
        // Sign the swap data
        (uint8 v, bytes32 r, bytes32 s) = signSwapData(swapData, PRIVATE_KEY);
        swapData.r = r;
        swapData.s = s;
        swapData.v = v;
        
        // Record initial balances
        uint256 initialVaultUSDC = usdc.balanceOf(address(vault));
        
        // Execute the swap as the operator
        vm.prank(swapOperator);
        vault.delegateSwap(swapData);

        // Verify the swap was submitted
        assertEq(vault.getSubmittedSwaps().length, 1, "Swap should be submitted");
        assertEq(vault.getSubmittedSwaps()[0], swapData.tradeId, "Swap should be submitted");
        
        // Verify token balance
        assertEq(usdc.balanceOf(address(vault)), initialVaultUSDC, "Vault USDC balance should remain the same in this mock test");
        
        // The real router would have transferred the tokens, but our mock doesn't actually do that
        // In a real scenario we'd check that the tokens were transferred to the router
    }
    
    // Test multiple delegate swaps to verify nonce increments
    function test_multipleDelegateSwaps() public {
        // First swap (ETH)
        bytes memory swapCalldata = abi.encodeWithSelector(
            OdosSwapRouterMock.swapCompact.selector
        );
        
        VaultTypes.DelegateSwap memory swapData1 = VaultTypes.DelegateSwap({
            tradeId: bytes32(uint256(0x01)), 
            chainId: block.chainid,
            inTokenHash: ETH_HASH,
            inTokenAmount: SWAP_AMOUNT / 2,
            to: address(odosRouter),
            value: SWAP_AMOUNT / 2,
            swapCalldata: swapCalldata,
            r: bytes32(0),
            s: bytes32(0),
            v: uint8(0)
        });
        
        // Sign and execute first swap
        (uint8 v, bytes32 r, bytes32 s) = signSwapData(swapData1, PRIVATE_KEY);
        swapData1.r = r;
        swapData1.s = s;
        swapData1.v = v;
        
        vm.prank(swapOperator);
        vault.delegateSwap(swapData1);
        
        // Verify nonce incremented
        assertEq(vault.getSubmittedSwaps().length, 1, "Swap should be submitted");
        assertEq(vault.getSubmittedSwaps()[0], swapData1.tradeId, "Swap should be submitted");
        
        // Second swap (USDC)
        uint256 usdcAmount = 500 * 10**6; // 500 USDC
        
        VaultTypes.DelegateSwap memory swapData2 = VaultTypes.DelegateSwap({
            tradeId: bytes32(uint256(0x02)),
            chainId: block.chainid,
            inTokenHash: USDC_HASH,
            inTokenAmount: usdcAmount,
            to: address(odosRouter),
            value: 0,
            swapCalldata: swapCalldata,
            r: bytes32(0),
            s: bytes32(0),
            v: uint8(0)
        });
        
        // Sign and execute second swap
        (v, r, s) = signSwapData(swapData2, PRIVATE_KEY);
        swapData2.r = r;
        swapData2.s = s;
        swapData2.v = v;
        
        vm.prank(swapOperator);
        vault.delegateSwap(swapData2);
        
        // Verify nonce incremented again
        assertEq(vault.getSubmittedSwaps().length, 2, "Swap should be submitted");
        assertEq(vault.getSubmittedSwaps()[1], swapData2.tradeId, "Swap should be submitted");
    }
    
    // Test invalid nonce
    function test_swapAlreadySubmitted() public {
        bytes memory swapCalldata = abi.encodeWithSelector(
            OdosSwapRouterMock.swapCompact.selector
        );
        
        VaultTypes.DelegateSwap memory swapData = VaultTypes.DelegateSwap({
            tradeId: bytes32(uint256(0x01)),
            chainId: block.chainid,
            inTokenHash: ETH_HASH,
            inTokenAmount: SWAP_AMOUNT,
            to: address(odosRouter),
            value: SWAP_AMOUNT,
            swapCalldata: swapCalldata,
            r: bytes32(0),
            s: bytes32(0),
            v: uint8(0)
        });
        
        // Sign the swap data
        (uint8 v, bytes32 r, bytes32 s) = signSwapData(swapData, PRIVATE_KEY);
        swapData.r = r;
        swapData.s = s;
        swapData.v = v;
        
        // Should fail due to invalid nonce
        vm.prank(swapOperator);
        vault.delegateSwap(swapData);
        vm.prank(swapOperator);
        vm.expectRevert(IVault.SwapAlreadySubmitted.selector);
        vault.delegateSwap(swapData);
    }
    
    // Test invalid signature
    function test_invalidSignature() public {
        bytes memory swapCalldata = abi.encodeWithSelector(
            OdosSwapRouterMock.swapCompact.selector
        );
        
        VaultTypes.DelegateSwap memory swapData = VaultTypes.DelegateSwap({
            tradeId: bytes32(uint256(0x01)),
            chainId: block.chainid,
            inTokenHash: ETH_HASH,
            inTokenAmount: SWAP_AMOUNT,
            to: address(odosRouter),
            value: SWAP_AMOUNT,
            swapCalldata: swapCalldata,
            r: bytes32(uint256(1234)), // Invalid signature
            s: bytes32(uint256(5678)),
            v: uint8(27)
        });
        
        // Should fail due to invalid signature
        vm.prank(swapOperator);
        vm.expectRevert("ECDSA: invalid signature");
        vault.delegateSwap(swapData);
    }

    // Revert if signer is not the swap signer
    function test_invalidSigner() public {
        bytes memory swapCalldata = abi.encodeWithSelector(
            OdosSwapRouterMock.swapCompact.selector
        );

        VaultTypes.DelegateSwap memory swapData = VaultTypes.DelegateSwap({
            tradeId: bytes32(uint256(0x01)),
            chainId: block.chainid,
            inTokenHash: ETH_HASH,
            inTokenAmount: SWAP_AMOUNT,
            to: address(odosRouter),
            value: SWAP_AMOUNT,
            swapCalldata: swapCalldata,
            r: bytes32(0),
            s: bytes32(0),
            v: uint8(0)
        });

        // Another private key
        uint256 anotherPrivateKey = 0xBEEF;
        
        // Sign the swap data
        (uint8 v, bytes32 r, bytes32 s) = signSwapData(swapData, anotherPrivateKey);
        swapData.r = r;
        swapData.s = s;
        swapData.v = v;

        vm.prank(swapOperator);
        vm.expectRevert(IVault.InvalidSwapSignature.selector);
        vault.delegateSwap(swapData);
    }

    function signSwapData(VaultTypes.DelegateSwap memory swap, uint256 privateKey) 
        internal
        pure 
        returns (uint8 v, bytes32 r, bytes32 s) 
    {
        bytes memory encoded = abi.encode(
            swap.tradeId,
            swap.chainId,
            swap.inTokenHash,
            swap.inTokenAmount,
            swap.to,
            swap.value,
            swap.swapCalldata
        );

        bytes32 digest = ECDSA.toEthSignedMessageHash(keccak256(encoded));
        (v, r, s) = vm.sign(privateKey, digest);

        return (v, r, s);
    }
    
    // Helper function to sign swap data
    function signSwapDataEIP712(VaultTypes.DelegateSwap memory swap, uint256 privateKey) 
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s) 
    {
        // Get domain separator
        bytes32 domainSeparator = SwapSignature.getDomainSeparator(
            "OrderlyVault",
            "1",
            address(vault)
        );
        
        // Create the struct hash
        bytes32 DELEGATE_SWAP_TYPEHASH = keccak256(
            "DelegateSwap(uint256 swapNonce,uint256 chainId,bytes32 inTokenHash,uint256 inTokenAmount,address to,uint256 value,bytes swapCalldata)"
        );
        
        bytes32 structHash = keccak256(
            abi.encode(
                DELEGATE_SWAP_TYPEHASH,
                swap.tradeId,
                swap.chainId,
                swap.inTokenHash,
                swap.inTokenAmount,
                swap.to,
                swap.value,
                keccak256(swap.swapCalldata)
            )
        );
        
        // Create the digest to sign
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        
        // Sign the digest
        (v, r, s) = vm.sign(privateKey, digest);
        
        return (v, r, s);
    }

    function test_revertSwapCompact() public {
        bytes memory swapCalldata = abi.encodeWithSelector(
            OdosSwapRouterMock.swapCompactRevert.selector
        );
        
        VaultTypes.DelegateSwap memory swapData = VaultTypes.DelegateSwap({
            tradeId: bytes32(uint256(0x01)),
            chainId: block.chainid,
            inTokenHash: ETH_HASH,
            inTokenAmount: SWAP_AMOUNT,
            to: address(odosRouter),
            value: SWAP_AMOUNT,
            swapCalldata: swapCalldata,
            r: bytes32(0),
            s: bytes32(0),
            v: uint8(0)
        });
        
        // Sign the swap data
        (uint8 v, bytes32 r, bytes32 s) = signSwapData(swapData, PRIVATE_KEY);
        swapData.r = r;
        swapData.s = s;
        swapData.v = v;

        vm.prank(swapOperator);
        vm.expectRevert("OdosSwapRouterMock: swapCompactRevert");
        // vm.expectRevert("Vault: Delegate Swap Transaction failed");
        vault.delegateSwap(swapData);
    }
}

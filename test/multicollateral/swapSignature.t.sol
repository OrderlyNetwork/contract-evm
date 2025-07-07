// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/library/SwapSignature.sol";
import "../../src/library/types/VaultTypes.sol";
import "forge-std/console.sol";

contract SwapSignatureTest is Test {
    // Test constants
    uint256 constant PRIVATE_KEY = 0xA11CE;
    address public signer;
    bytes32 constant DOMAIN_SEPARATOR_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 constant DELEGATE_SWAP_TYPEHASH = keccak256(
        "DelegateSwap(uint256 swapNonce,uint256 chainId,bytes32 inTokenHash,uint256 inTokenAmount,address to,uint256 value,bytes swapCalldata)"
    );
    
    // Test data
    bytes32 constant USDC_HASH = keccak256(abi.encodePacked("USDC"));
    
    function setUp() public {
        signer = vm.addr(PRIVATE_KEY);
    }
    
    function test_getDomainSeparator() public {
        bytes32 expectedDomainSeparator = keccak256(
            abi.encode(
                DOMAIN_SEPARATOR_TYPEHASH,
                keccak256(bytes("OrderlyVault")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
        
        bytes32 actualDomainSeparator = SwapSignature.getDomainSeparator(
            "OrderlyVault",
            "1",
            address(this)
        );
        
        assertEq(actualDomainSeparator, expectedDomainSeparator, "Domain separator mismatch");
    }
    
    function test_validateSwapSignature_validSignature() public {
        // Create a swap request
        VaultTypes.DelegateSwap memory swap = createTestSwapData();
        
        // Sign the swap data
        (, VaultTypes.DelegateSwap memory signedSwap) = signSwapData(swap);
        
        // Verify the signature is valid
        bool isValid = SwapSignature.validateSwapSignature(signer, signedSwap);
        assertTrue(isValid, "Valid signature should be verified");
    }
    
    function test_validateSwapSignature_invalidSigner() public {
        // Create a swap request
        VaultTypes.DelegateSwap memory swap = createTestSwapData();
        
        // Sign the swap data
        (, VaultTypes.DelegateSwap memory signedSwap) = signSwapData(swap);
        
        // Try to verify with the wrong signer
        address wrongSigner = vm.addr(0xB0B);
        bool isValid = SwapSignature.validateSwapSignature(wrongSigner, signedSwap);
        assertFalse(isValid, "Signature should be invalid for wrong signer");
    }
    
    function test_validateSwapSignature_tamperedData() public {
        // Create a swap request
        VaultTypes.DelegateSwap memory swap = createTestSwapData();
        
        // Sign the swap data
        (, VaultTypes.DelegateSwap memory signedSwap) = signSwapData(swap);
        
        // Tamper with the data after signing
        signedSwap.inTokenAmount += 100; // Change amount
        
        // Verify the signature is now invalid
        bool isValid = SwapSignature.validateSwapSignature(signer, signedSwap);
        assertFalse(isValid, "Signature should be invalid for tampered data");
    }
    
    function test_validateSwapSignature_tamperedSignature() public {
        // Create a swap request
        VaultTypes.DelegateSwap memory swap = createTestSwapData();
        
        // Sign the swap data
        (, VaultTypes.DelegateSwap memory signedSwap) = signSwapData(swap);
        
        // Tamper with the signature
        signedSwap.r = bytes32(uint256(signedSwap.r) + 1);
        
        // Verify the signature is now invalid
        bool isValid = SwapSignature.validateSwapSignature(signer, signedSwap);
        assertFalse(isValid, "Signature should be invalid when tampered with");
    }
    
    function test_validateSwapSignature_differentChainId() public {
        // Create a swap request
        VaultTypes.DelegateSwap memory swap = createTestSwapData();
        
        // Sign the swap data
        (, VaultTypes.DelegateSwap memory signedSwap) = signSwapData(swap);
        
        // Change the chainId after signing
        signedSwap.chainId = 999; // Different chain ID
        console.log("signedSwap.chainId");
        console.logUint(signedSwap.chainId);
        console.log("block.chainid");
        console.logUint(block.chainid);
        console.log(signer);
        
        // Verify the signature is now invalid
        // expect revert with "Signature is invalid"
        bool isValid = SwapSignature.validateSwapSignature(signer, signedSwap);
        assertFalse(isValid, "Signature should be invalid for different chainId");
    }
    
    function test_validateSwapSignature_differentSwapCalldata() public {
        // Create a swap request
        VaultTypes.DelegateSwap memory swap = createTestSwapData();
        
        // Sign the swap data
        (, VaultTypes.DelegateSwap memory signedSwap) = signSwapData(swap);
        
        // Change the calldata after signing
        signedSwap.swapCalldata = abi.encodeWithSignature("differentFunction()");
        
        // Verify the signature is now invalid
        bool isValid = SwapSignature.validateSwapSignature(signer, signedSwap);
        assertFalse(isValid, "Signature should be invalid for different calldata");
    }
    
    function test_ecrecoverInSwapSignature() public {
        // Create a swap request
        VaultTypes.DelegateSwap memory swap = createTestSwapData();
        
        // Sign the swap data
        (bytes32 digest, VaultTypes.DelegateSwap memory signedSwap) = signSwapData(swap);
        
        // Recover the signer directly
        address recoveredAddress = SwapSignature.recover(
            digest, 
            signedSwap.r, 
            signedSwap.s, 
            signedSwap.v
        );
        
        assertEq(recoveredAddress, signer, "Recovered address should match signer");
    }
    
    // Helper function to create test swap data
    function createTestSwapData() internal view returns (VaultTypes.DelegateSwap memory) {
        return VaultTypes.DelegateSwap({
            tradeId: bytes32(uint256(0x01)),
            chainId: block.chainid,
            inTokenHash: USDC_HASH,
            inTokenAmount: 1000000, // 1 USDC
            to: address(0xCAFE),
            value: 0,
            swapCalldata: abi.encodeWithSignature("swap()"),
            r: 0,
            s: 0,
            v: 0
        });
    }
    
    // Helper function to sign swap data
    function signSwapData(VaultTypes.DelegateSwap memory swap) 
        internal 
        view
        returns (bytes32 digest, VaultTypes.DelegateSwap memory signedSwap) 
    {
        // Deep copy the swap data
        signedSwap = VaultTypes.DelegateSwap({
            tradeId: swap.tradeId,
            chainId: swap.chainId,
            inTokenHash: swap.inTokenHash,
            inTokenAmount: swap.inTokenAmount,
            to: swap.to,
            value: swap.value,
            swapCalldata: swap.swapCalldata,
            r: 0,
            s: 0,
            v: 0
        });
        
        // Get domain separator
        bytes32 domainSeparator = SwapSignature.getDomainSeparator(
            "OrderlyVault",
            "1",
            address(this)
        );
        
        // Create the struct hash
        bytes32 structHash = keccak256(
            abi.encode(
                DELEGATE_SWAP_TYPEHASH,
                signedSwap.tradeId,
                signedSwap.chainId,
                signedSwap.inTokenHash,
                signedSwap.inTokenAmount,
                signedSwap.to,
                signedSwap.value,
                keccak256(signedSwap.swapCalldata)
            )
        );
        
        // Create the digest to sign
        digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        
        // Sign the digest and get r, s, v components
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, digest);
        
        // Update swap with signature components
        signedSwap.r = r;
        signedSwap.s = s;
        signedSwap.v = v;
        
        return (digest, signedSwap);
    }
}

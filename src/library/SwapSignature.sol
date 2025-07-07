// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.26;

import "../interface/IVault.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

/// @title SwapSignature Library
/// @author Orderly
/// @notice Library for verifying EIP-712 signatures for swap transactions
library SwapSignature {
    // TypeHash for DelegateSwap
    bytes32 private constant DELEGATE_SWAP_TYPEHASH = keccak256(
        "DelegateSwap(uint256 swapNonce,uint256 chainId,bytes32 inTokenHash,uint256 inTokenAmount,address to,uint256 value,bytes swapCalldata)"
    );

    // Domain separator components
    bytes32 private constant EIP712_DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    
    /// @notice Calculates the EIP-712 domain separator
    /// @param name The name of the contract
    /// @param version The version of the contract
    /// @param verifyingContract The address of the contract that will verify the signature
    /// @return The domain separator
    function getDomainSeparator(string memory name, string memory version, address verifyingContract) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                block.chainid,
                verifyingContract
            )
        );
    }
    
    /// @notice Recovers the signer's address from signature components
    /// @param hash The hash that was signed
    /// @param r The r component of the signature
    /// @param s The s component of the signature
    /// @param v The v component of the signature
    /// @return The address of the signer
    function recover(bytes32 hash, bytes32 r, bytes32 s, uint8 v) internal pure returns (address) {
        return ECDSA.recover(hash, v, r, s);
    }
    
    /// @notice Validates a signature for a swap transaction
    /// @param expectedSigner The expected signer of the transaction
    /// @param data The swap request data
    /// @return Whether the signature is valid
    function validateSwapSignature(
        address expectedSigner,
        VaultTypes.DelegateSwap memory data
    ) internal view returns (bool) {

        bytes32 domainSeparator = getDomainSeparator("OrderlyVault", "1", address(this));

        // Create struct hash according to EIP-712
        bytes32 structHash = keccak256(
            abi.encode(
                DELEGATE_SWAP_TYPEHASH,
                data.tradeId,
                data.chainId,
                data.inTokenHash,
                data.inTokenAmount,
                data.to,
                data.value,
                keccak256(data.swapCalldata)
            )
        );
        
        // Create the digest to sign (EIP-712 compliant)
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        
        // Recover the signer's address
        address actualSigner = recover(digest, data.r, data.s, data.v);
        
        // Check if the signer matches the expected signer
        return actualSigner == expectedSigner;
    }
}

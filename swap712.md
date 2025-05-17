# Orderly DelegateSwap EIP-712 Signatures

This document explains how to implement and use EIP-712 typed signatures for Orderly's DelegateSwap functionality.

## Overview

EIP-712 is a standard for typed structured data hashing and signing in Ethereum. It improves the user experience when signing data by displaying the data in a structured and readable way in wallet interfaces, and provides stronger security guarantees compared to standard ethereum message signing (`eth_sign`).

The Orderly Vault implements delegated swap functionality that uses EIP-712 signatures to authorize swaps from the vault via external operators.

## The DelegateSwap Structure

The `DelegateSwap` structure contains all the necessary information for executing a swap operation:

```solidity
struct DelegateSwap {
    uint256 swapNonce;
    uint256 chainId;
    bytes32 inTokenHash;
    uint256 inTokenAmount;
    address to;
    uint256 value;
    bytes swapCalldata;
    // signature
    bytes32 r;
    bytes32 s;
    uint8 v;
}
```

## Generating EIP-712 Signatures with TypeScript and ethers.js v6

Below is a TypeScript implementation for generating EIP-712 signatures for DelegateSwap operations using ethers.js v6:

```typescript
import { ethers } from 'ethers';

// Define the domain
const domain = {
  name: 'OrderlyVault',
  version: '1',
  chainId: 1, // Replace with your chain ID
  verifyingContract: '0xYourVaultContractAddress' // Replace with your vault address
};

// Define the types
const types = {
  DelegateSwap: [
    { name: 'swapNonce', type: 'uint256' },
    { name: 'chainId', type: 'uint256' },
    { name: 'inTokenHash', type: 'bytes32' },
    { name: 'inTokenAmount', type: 'uint256' },
    { name: 'to', type: 'address' },
    { name: 'value', type: 'uint256' },
    { name: 'swapCalldata', type: 'bytes' }
  ]
};

/**
 * Generate an EIP-712 signature for a delegate swap
 * @param signer The ethers.js Signer instance
 * @param swapData The swap data to sign
 * @returns The signature components (v, r, s)
 */
async function signDelegateSwap(
  signer: ethers.Signer,
  swapData: {
    swapNonce: bigint | string;
    chainId: bigint | string;
    inTokenHash: string;
    inTokenAmount: bigint | string;
    to: string;
    value: bigint | string;
    swapCalldata: string;
  }
): Promise<{ v: number; r: string; s: string }> {
  // Format the data for signing
  const formattedData = {
    swapNonce: swapData.swapNonce.toString(),
    chainId: swapData.chainId.toString(),
    inTokenHash: swapData.inTokenHash,
    inTokenAmount: swapData.inTokenAmount.toString(),
    to: swapData.to,
    value: swapData.value.toString(),
    swapCalldata: swapData.swapCalldata
  };

  // Sign the typed data
  const signature = await signer.signTypedData(domain, types, formattedData);
  
  // Split the signature into r, s, v components
  const sig = ethers.Signature.from(signature);
  
  return {
    v: sig.v,
    r: sig.r,
    s: sig.s
  };
}
```

### Example Usage

Here's how to use the above function to sign a swap request:

```typescript
import { ethers } from 'ethers';

async function main() {
  // Connect to provider
  const provider = new ethers.JsonRpcProvider('YOUR_RPC_URL');
  
  // Create a wallet with the private key
  const wallet = new ethers.Wallet('YOUR_PRIVATE_KEY', provider);
  
  // Create the swap data
  const swapData = {
    swapNonce: 0n, // Should match the current nonce in the vault
    chainId: 1n, // The chain ID
    inTokenHash: ethers.keccak256(ethers.toUtf8Bytes('WETH')), // Token hash
    inTokenAmount: ethers.parseEther('1.0'), // 1 WETH
    to: '0x19cEeAd7105607Cd444F5ad10dd51356436095a1', // Odos Router address
    value: 0n, // No ETH value being sent
    swapCalldata: '0x83bd37f9...' // The calldata for the swap
  };
  
  // Sign the data
  const signature = await signDelegateSwap(wallet, swapData);
  
  console.log('Signature:', signature);
  
  // Construct the final DelegateSwap object to send to the contract
  const delegateSwap = {
    ...swapData,
    v: signature.v,
    r: signature.r,
    s: signature.s
  };
  
  console.log('DelegateSwap:', delegateSwap);
}

main().catch(console.error);
```

## Calculating the Token Hash

Token hashes are calculated using `keccak256(abi.encodePacked(tokenSymbol))`. Here's how to calculate them in TypeScript:

```typescript
import { ethers } from 'ethers';

function calculateTokenHash(tokenSymbol: string): string {
  return ethers.keccak256(ethers.toUtf8Bytes(tokenSymbol));
}

// Examples
const ethHash = calculateTokenHash('ETH');
const wethHash = calculateTokenHash('WETH');
const usdcHash = calculateTokenHash('USDC');

console.log('ETH Hash:', ethHash);
console.log('WETH Hash:', wethHash);
console.log('USDC Hash:', usdcHash);
```

## Verifying EIP-712 Signatures

Signatures are verified on-chain by the `SwapSignature.validateSwapSignature()` function, but if you need to verify a signature off-chain:

```typescript
import { ethers } from 'ethers';

async function verifyDelegateSwapSignature(
  signerAddress: string,
  swapData: {
    swapNonce: bigint | string;
    chainId: bigint | string;
    inTokenHash: string;
    inTokenAmount: bigint | string;
    to: string;
    value: bigint | string;
    swapCalldata: string;
    v: number;
    r: string;
    s: string;
  },
  domain: {
    name: string;
    version: string;
    chainId: number;
    verifyingContract: string;
  }
): Promise<boolean> {
  // Format the data for verification
  const formattedData = {
    swapNonce: swapData.swapNonce.toString(),
    chainId: swapData.chainId.toString(),
    inTokenHash: swapData.inTokenHash,
    inTokenAmount: swapData.inTokenAmount.toString(),
    to: swapData.to,
    value: swapData.value.toString(),
    swapCalldata: swapData.swapCalldata
  };
  
  // Recreate the signature
  const signature = ethers.Signature.from({
    v: swapData.v,
    r: swapData.r,
    s: swapData.s
  }).serialized;
  
  // Verify the signature
  const types = {
    DelegateSwap: [
      { name: 'swapNonce', type: 'uint256' },
      { name: 'chainId', type: 'uint256' },
      { name: 'inTokenHash', type: 'bytes32' },
      { name: 'inTokenAmount', type: 'uint256' },
      { name: 'to', type: 'address' },
      { name: 'value', type: 'uint256' },
      { name: 'swapCalldata', type: 'bytes' }
    ]
  };
  
  // Recover the signer
  const recoveredAddress = ethers.verifyTypedData(
    domain,
    types,
    formattedData,
    signature
  );
  
  // Check if the recovered address matches the expected signer
  return recoveredAddress.toLowerCase() === signerAddress.toLowerCase();
}
```

## Complete Flow Example

Here's a complete example showing the entire flow from creating a swap request, signing it, and executing it:

```typescript
import { ethers } from 'ethers';

// ABI snippets for the vault contract
const vaultAbi = [
  "function swapNonce() external view returns (uint256)",
  "function delegateSwap((uint256,uint256,bytes32,uint256,address,uint256,bytes,bytes32,bytes32,uint8)) external"
];

async function executeSwap() {
  // Setup provider and wallet
  const provider = new ethers.JsonRpcProvider('YOUR_RPC_URL');
  const signer = new ethers.Wallet('SIGNER_PRIVATE_KEY', provider);
  const operator = new ethers.Wallet('OPERATOR_PRIVATE_KEY', provider);
  
  // Vault contract address and instance
  const vaultAddress = '0xYourVaultContractAddress';
  const vault = new ethers.Contract(vaultAddress, vaultAbi, provider);
  
  // Get current nonce from the vault
  const currentNonce = await vault.swapNonce();
  
  // Define the domain for EIP-712 signing
  const domain = {
    name: 'OrderlyVault',
    version: '1',
    chainId: (await provider.getNetwork()).chainId,
    verifyingContract: vaultAddress
  };
  
  // Prepare the swap data
  const swapData = {
    swapNonce: currentNonce,
    chainId: BigInt(domain.chainId),
    inTokenHash: ethers.keccak256(ethers.toUtf8Bytes('WETH')),
    inTokenAmount: ethers.parseEther('1.0'),
    to: '0x19cEeAd7105607Cd444F5ad10dd51356436095a1', // Router address
    value: 0n,
    swapCalldata: '0x83bd37f9...' // The calldata for the swap
  };
  
  // Sign the data
  const { v, r, s } = await signDelegateSwap(signer, swapData);
  
  // Create the complete swap object
  const delegateSwap = {
    ...swapData,
    v,
    r,
    s
  };
  
  // Execute the swap from the operator
  const vaultWithOperator = vault.connect(operator);
  const tx = await vaultWithOperator.delegateSwap(delegateSwap);
  
  console.log('Transaction hash:', tx.hash);
  
  // Wait for confirmation
  const receipt = await tx.wait();
  console.log('Transaction confirmed in block:', receipt.blockNumber);
}

executeSwap().catch(console.error);
```

## Generating Signatures Offline

For enhanced security, you might want to generate signatures offline without connecting to an RPC endpoint. Here's how to do it:

```typescript
import { ethers } from 'ethers';
import { writeFileSync } from 'fs';

async function generateOfflineSignature() {
  // Create a wallet without a provider for offline signing
  const wallet = new ethers.Wallet('YOUR_PRIVATE_KEY');
  
  // Define the domain (must know chain ID in advance)
  const domain = {
    name: 'OrderlyVault',
    version: '1',
    chainId: 1, // Explicitly set the chain ID
    verifyingContract: '0xYourVaultContractAddress'
  };
  
  // Prepare swap data
  const swapData = {
    swapNonce: 0n, // Nonce to use
    chainId: 1n, // Must match domain chainId
    inTokenHash: ethers.keccak256(ethers.toUtf8Bytes('WETH')),
    inTokenAmount: ethers.parseEther('1.0'),
    to: '0x19cEeAd7105607Cd444F5ad10dd51356436095a1',
    value: 0n,
    swapCalldata: '0x83bd37f9...'
  };
  
  // Sign the data
  const { v, r, s } = await signDelegateSwap(wallet, swapData);
  
  // Final swap object to be sent to the contract later
  const delegateSwap = {
    ...swapData,
    v,
    r,
    s
  };
  
  // Export the signed data to a JSON file
  writeFileSync(
    'signed_swap.json',
    JSON.stringify({
      swapNonce: delegateSwap.swapNonce.toString(),
      chainId: delegateSwap.chainId.toString(),
      inTokenHash: delegateSwap.inTokenHash,
      inTokenAmount: delegateSwap.inTokenAmount.toString(),
      to: delegateSwap.to,
      value: delegateSwap.value.toString(),
      swapCalldata: delegateSwap.swapCalldata,
      v: delegateSwap.v,
      r: delegateSwap.r,
      s: delegateSwap.s
    }, null, 2)
  );
  
  console.log('Signed swap data saved to signed_swap.json');
}

generateOfflineSignature().catch(console.error);
```

Then, to execute the swap using the pre-signed data:

```typescript
import { ethers } from 'ethers';
import { readFileSync } from 'fs';

async function executePreSignedSwap() {
  // Load the signed swap data
  const signedData = JSON.parse(readFileSync('signed_swap.json', 'utf8'));
  
  // Connect to provider and create operator wallet
  const provider = new ethers.JsonRpcProvider('YOUR_RPC_URL');
  const operator = new ethers.Wallet('OPERATOR_PRIVATE_KEY', provider);
  
  // Convert string values back to appropriate types
  const delegateSwap = {
    swapNonce: BigInt(signedData.swapNonce),
    chainId: BigInt(signedData.chainId),
    inTokenHash: signedData.inTokenHash,
    inTokenAmount: BigInt(signedData.inTokenAmount),
    to: signedData.to,
    value: BigInt(signedData.value),
    swapCalldata: signedData.swapCalldata,
    v: signedData.v,
    r: signedData.r,
    s: signedData.s
  };
  
  // Create contract instance
  const vaultAbi = [
    "function delegateSwap((uint256,uint256,bytes32,uint256,address,uint256,bytes,bytes32,bytes32,uint8)) external"
  ];
  const vaultAddress = '0xYourVaultContractAddress';
  const vault = new ethers.Contract(vaultAddress, vaultAbi, operator);
  
  // Execute the swap
  const tx = await vault.delegateSwap(delegateSwap);
  console.log('Transaction hash:', tx.hash);
  
  const receipt = await tx.wait();
  console.log('Transaction confirmed in block:', receipt.blockNumber);
}

executePreSignedSwap().catch(console.error);
```

## Security Considerations

1. **Nonce Management**: Always use the current nonce from the vault to prevent replay attacks.
2. **Chain ID**: Include the correct chain ID in the signature to prevent cross-chain replay attacks.
3. **Private Key Security**: Keep the signer's private key secure at all times.
4. **Signature Verification**: Always verify signatures before submitting transactions.
5. **Gas Estimation**: Estimate gas properly for swap transactions, especially when working with complex swaps.

## Testing Signatures

It's recommended to test your signatures locally before executing them on-chain:

```typescript
async function testSignature() {
  // Create signature as before
  const { v, r, s } = await signDelegateSwap(wallet, swapData);
  
  // Verify the signature locally
  const isValid = await verifyDelegateSwapSignature(
    wallet.address,
    { ...swapData, v, r, s },
    domain
  );
  
  console.log('Signature valid:', isValid);
}
```

By following this guide, you should be able to implement EIP-712 signatures for DelegateSwap operations in the Orderly protocol using TypeScript and ethers. 
# Orderly DelegateSwap EIP-712 Simplified Guide

## Struct Definition

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

## Contract Method ABI

```json
"function delegateSwap((uint256,uint256,bytes32,uint256,address,uint256,bytes,bytes32,bytes32,uint8)) external"
```

## Message Definition

```typescript
// Domain definition
const domain = {
  name: 'OrderlyVault',
  version: '1',
  chainId: 1, // Replace with your chain ID
  verifyingContract: '0xYourVaultContractAddress'
};

// Type definition
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
```

## Calculating Digest Example

```typescript
import { ethers } from 'ethers';

// Domain parameters
const domain = {
  name: 'OrderlyVault',
  version: '1',
  chainId: 1,
  verifyingContract: '0x123456789abcdef0123456789abcdef012345678'
};

// Types for EIP-712
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

// Message parameters
const message = {
  swapNonce: 5n,
  chainId: 1n,
  inTokenHash: '0xaaaebeba3810b1e6b70781f14b2d72c1cb89c0b2b320c43bb67ff79f562f5ff4', // ETH
  inTokenAmount: ethers.parseEther('1.0'),
  to: '0x19cEeAd7105607Cd444F5ad10dd51356436095a1',
  value: 0n,
  swapCalldata: '0x83bd37f9000000000000000000000000000000000000000000'
};

// Calculate digest
function calculateDigest() {
  const digest = ethers.TypedDataEncoder.hash(domain, types, message);
  console.log('EIP-712 Digest:', digest);
  return digest;
}

// Sign message
async function signMessage(wallet) {
  const signature = await wallet.signTypedData(domain, types, message);
  const sig = ethers.Signature.from(signature);
  
  return {
    v: sig.v,
    r: sig.r,
    s: sig.s
  };
}
```

## Token Hashes

```
ETH:  0xaaaebeba3810b1e6b70781f14b2d72c1cb89c0b2b320c43bb67ff79f562f5ff4
USDT: 0x8b1a1d9c2b109e527c9134b25b1a1833b16b6594f92daa9f6d9b7a6024bce9d0
USDC: 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa
```

## Complete Example

```typescript
import { ethers } from 'ethers';

async function main() {
  // Setup
  const privateKey = "0x..."; // Your private key
  const wallet = new ethers.Wallet(privateKey);
  
  // Contract details
  const vaultAddress = "0x..."; // OrderlyVault contract address
  
  // Domain parameters
  const domain = {
    name: 'OrderlyVault',
    version: '1',
    chainId: 1,
    verifyingContract: vaultAddress
  };
  
  // Message parameters
  const message = {
    swapNonce: 5n,
    chainId: 1n,
    inTokenHash: '0xaaaebeba3810b1e6b70781f14b2d72c1cb89c0b2b320c43bb67ff79f562f5ff4', // ETH
    inTokenAmount: ethers.parseEther('1.0'),
    to: '0x19cEeAd7105607Cd444F5ad10dd51356436095a1', // Router address
    value: 0n,
    swapCalldata: '0x83bd37f9000000000000000000000000000000000000000000'
  };
  
  // Get the EIP-712 digest
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
  
  // Calculate the digest
  const digest = ethers.TypedDataEncoder.hash(domain, types, message);
  console.log('EIP-712 Digest:', digest);
  
  // Sign the message
  const signature = await wallet.signTypedData(domain, types, message);
  const sig = ethers.Signature.from(signature);
  
  console.log('Signature:', {
    v: sig.v,
    r: sig.r,
    s: sig.s
  });
  
  // The complete DelegateSwap object
  const delegateSwap = {
    ...message,
    v: sig.v,
    r: sig.r,
    s: sig.s
  };
  
  console.log('DelegateSwap object:', delegateSwap);
}

main().catch(console.error);
```

# solidity code
```solidity

    bytes32 private constant DELEGATE_SWAP_TYPEHASH = keccak256(
        "DelegateSwap(uint256 swapNonce,uint256 chainId,bytes32 inTokenHash,uint256 inTokenAmount,address to,uint256 value,bytes swapCalldata)"
    );
    bytes32 private constant EIP712_DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

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


    bytes32 domainSeparator = getDomainSeparator("OrderlyVault", "1", address(this));

    // Create struct hash according to EIP-712
    bytes32 structHash = keccak256(
            abi.encode(
                DELEGATE_SWAP_TYPEHASH,
                data.swapNonce,
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
```
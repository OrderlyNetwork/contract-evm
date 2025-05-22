# Orderly Multicolateral Test Guid

# Prerequisite

# Deposit ETH
Support only Native ETH. ETH token hash is `0xaaaebeba3810b1e6b70781f14b2d72c1cb89c0b2b320c43bb67ff79f562f5ff4`. You can call method `function deposit(VaultTypes.VaultDepositFE calldata data)` to deposit ETH.
The definition of `VaultDepositFE` is as follows:
```solidity
    struct VaultDepositFE {
        bytes32 accountId;
        bytes32 brokerHash;
        bytes32 tokenHash;
        uint128 tokenAmount;
    }
```
where the token hash should be ETH token hash. And when you call the method. You have to set the tx value to the amount of ETH you want to deposit.

ETH has decimal 18 on both base-sepolia, but 8 on orderly-sepolia.

# Deposit USDT 
There is a test USDT: `0x01a6810727db185bBf7f30Ec158C3ac8b8112627` with token hash `0x8b1a1d9c2b109e527c9134b25b1a1833b16b6594f92daa9f6d9b7a6024bce9d0`. You can call method `function deposit(VaultTypes.VaultDepositFE calldata data)` to deposit USDT.

If you do not have enough USDT, you can call method `function mint(address to, uint256 amount)` of `ERC20Mock` to get test USDT.

USDT has decimal 8 on both base-sepolia and orderly-sepolia.

# DelegateSwap
There are two roles: Swap Operator and Swap Signer. Swap Operator is responsible for calling `function delegateSwap(DelegateSwap calldata data)` to swap. Swap Signer is responsible for signing the message by EIP712 standard.

Please provide the address of Swap Operator and Swap Signer to @lewis to set the role.

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

## 712 Message Definition

```typescript
// Domain definition
const domain = {
  name: 'OrderlyVault',
  version: '1',
  chainId: 84532, // Replace with your chain ID
  verifyingContract: '0x2A5b650A894409372DDeE241EDAC92d4152bE24d'
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

## Token Hashes

```
testUSDT Address:0x01a6810727db185bBf7f30Ec158C3ac8b8112627
ETH:  0xaaaebeba3810b1e6b70781f14b2d72c1cb89c0b2b320c43bb67ff79f562f5ff4
USDT: 0x8b1a1d9c2b109e527c9134b25b1a1833b16b6594f92daa9f6d9b7a6024bce9d0
USDC: 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa
```

## Solidity Example

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
    chainId: 84532,
    verifyingContract: vaultAddress
  };
  
  // Message parameters
  const message = {
    swapNonce: 5n,
    chainId: 84532n,
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
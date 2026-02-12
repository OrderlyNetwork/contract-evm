# Introduction

This repo is built with Foundry, including the scipts for test and deployment.

The major content is about the contracts for Orderly V2, including the Ledger and Vault contracts.

A submodule inside `lib` folder is used for the contracts of Cross-Chain, named **cross-chain-relay**. For the information of this submodule, please refer to [cross-chain-relay](https://gitlab.com/orderlynetwork/orderly-v2/evm-cross-chain)

## Usage

Install dependencies

```sh
forge install
```

Update submodule

```sh
git submodule update
```

Build

```sh
forge build
```

Test

```sh
forge test -vvvv
```

# Contract Architecture

## Overview

Orderly V2 is a cross-chain perpetual DEX. The Ledger chain holds all account states and positions; each supported chain deploys a Vault to custody user tokens. The off-chain engine submits trades and events through the OperatorManager, while cross-chain messages flow through LayerZero.

## Contract Relationship

```
                         ┌──────────────────┐
                         │  Operator (EOA)  │
                         └────────┬─────────┘
                                  │
                    ┌─────────────▼───────────────┐
                    │      OperatorManager        │
                    │  ┌───────────┬────────────┐ │
                    │  │  ImplA    │   ImplB    │ │  ◄── OperatorManagerZip
                    │  │(trades,  │ (events)    │ │      (calldata compression)
                    │  │ prices,  │             │ │
                    │  │rebalance)│             │ │
                    │  └───────────┴────────────┘ │
                    └──────┬───────────┬──────────┘
                           │           │
              price/funding│           │ trades & events
                           ▼           ▼
                  ┌──────────┐   ┌──────────────────────────────────┐
                  │  Market  │   │            Ledger                │
                  │ Manager  │   │  ┌───────┬───────┬───────┬─────┐ │
                  └──────────┘   │  │ImplA  │ImplB  │ImplC  │ImplD│ │
                                 │  │core   │batch  │solana │swap │ │
                                 │  └───────┴───────┴───────┴─────┘ │
                                 └──┬────────┬────────┬─────────────┘
                                    │        │        │
                         ┌──────────▼┐ ┌─────▼─────┐  │
                         │   Vault   │ │    Fee    │  │
                         │  Manager  │ │  Manager  │  │
                         └───────────┘ └───────────┘  │
                                                      │
                                        ┌─────────────▼──────────────┐
                                        │    CrossChainManager       │
                                        │    (CCTP / LayerZero)      │
                                        └─────────────┬──────────────┘
                                                      │
                                              ┌───────▼───────┐
                                              │  Vault (L1/L2)│
                                              │  per-chain    │
                                              └───────────────┘
```

## Vault ↔ Ledger Cross-Chain Topology

Ledger 部署在 Orderly L2（Settlement Layer），各 Vault 部署在支持的链上。两侧通过各自的 CrossChainManager 经由 **LayerZero V2** 通道通信。

```
                              Orderly L2 (Settlement Layer)
          ┌──────────────────────────────────────────────────────────┐
          │  Ledger    VaultManager    MarketManager    FeeManager   │
          │                    │                                     │
          │          LedgerCrossChainManager                         │
          └────────────────────┬─────────────────────────────────────┘
                               │
                        LayerZero V2 / CCTP
                               │
                ┌──────────────┼──────────────┐
                │              │              │
        ┌───────▼────────┐     │     ┌────────▼───────┐
        │   Ethereum     │     │     │    Solana      │
        │ ┌────────────┐ │     │     │ ┌────────────┐ │
        │ │   Vault    │ │     │     │ │   Vault    │ │
        │ │  + CCMgr   │ │     │     │ │ (Program)  │ │
        │ └────────────┘ │     │     │ └────────────┘ │
        └────────────────┘     │     └────────────────┘
                               │
                       ┌───────▼────────┐
                       │  Other EVM L2  │
                       │  (Arb, Base,   │
                       │   OP, ...)     │
                       └────────────────┘
```

**Cross-chain message flows:**

| Flow | Direction | Description |
|---|---|---|
| **Deposit** | Vault → Ledger | User deposits on source chain, Vault locks tokens, CCMgr sends message to Ledger via LayerZero V2 |
| **Withdraw** | Ledger → Vault | Engine processes withdraw event, Ledger freezes balance, CCMgr sends message to Vault to release tokens |
| **Rebalance** | Ledger ↔ Vault | Operator triggers burn/mint to move liquidity between chains via CCTP |

## Core Contracts

| Contract | Role |
|---|---|
| **Ledger** | Central ledger. Stores all user accounts, token balances, and perp positions. Split into ImplA/B/C/D via `delegatecall` to bypass EIP-170 size limit. |
| **OperatorManager** | Entry point for the off-chain engine. Validates operator signatures and routes trades/events to Ledger. Split into ImplA/B. |
| **VaultManager** | Tracks per-chain token balances, manages allowed tokens/brokers/symbols, handles rebalance state machine. |
| **MarketManager** | Stores perpetual market configs: mark price, index price, funding rates, margin parameters. |
| **FeeManager** | Manages fee collector accounts (withdraw fees, trading fees, broker fees). |
| **Vault** | Deployed per-chain. Custodies ERC20 tokens, handles user deposit/withdraw on that chain. |
| **OperatorManagerZip** | Decompresses calldata before forwarding to OperatorManager, reducing L1 gas costs. |

## Access Control

- **Ledger.execute\*()** — only callable by OperatorManager
- **Ledger.accountDeposit() / withdrawFinish()** — only callable by CrossChainManager
- **VaultManager / FeeManager mutations** — only callable by Ledger (`LedgerComponent`)
- **MarketManager price updates** — only callable by OperatorManager (`OperatorManagerComponent`)
- **OperatorManager uploads** — only callable by operator EOA or OperatorManagerZip

## Key Design Patterns

- **Upgradeable Proxies** — All core contracts use OZ Upgradeable with storage gaps (`__gap`)
- **DataLayout Separation** — Storage defined in `*DataLayout.sol`, logic in main contracts
- **Delegatecall Split** — Ledger/OperatorManager delegate to multiple Impl contracts for EIP-170 compliance
- **Component Pattern** — VaultManager, MarketManager, FeeManager inherit `LedgerComponent` / `OperatorManagerComponent` for caller restriction
- **Transient Storage** — `LedgerImplB` uses EVM transient storage for gas-efficient batch trade processing
- **Dual-Chain Auth** — ECDSA (EIP-712) for EVM wallets, Ed25519 for Solana wallets
- **Hash-Based IDs** — Brokers, tokens, symbols identified by `keccak256` hashes

## Source Layout

```
src/
├── Ledger.sol / LedgerImplA~D.sol      # Core ledger + implementations
├── OperatorManager.sol / ImplA~B.sol    # Operator entry + implementations
├── VaultManager.sol                     # Token & chain balance tracking
├── MarketManager.sol                    # Perp market configuration
├── FeeManager.sol                       # Fee collection
├── Vault.sol                            # Per-chain token custody
├── LedgerComponent.sol                  # Base: onlyLedger modifier
├── OperatorManagerComponent.sol         # Base: onlyOperatorManager modifier
├── LedgerDataLayout.sol                 # Ledger storage slots
├── OperatorManagerDataLayout.sol        # OperatorManager storage slots
├── library/
│   ├── types/                           # Data structs (Account, Perp, Event, Market, Rebalance)
│   ├── typesHelper/                     # Struct helper functions
│   ├── Signature.sol                    # ECDSA + Ed25519 verification
│   └── Ed25519/                         # Ed25519 crypto library
├── zip/                                 # Calldata compression layer
├── oz5Revised/                          # Revised OZ5 AccessControl & ReentrancyGuard
└── interface/                           # All interface definitions
```

# License

Apache-2.0

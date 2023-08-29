# poc

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

# Contract overview

## Layout

see standard [foundry project layout](https://book.getfoundry.sh/projects/project-layout)

## Src

1. dataLayout

   Complicated dataLayout, or slot storage for contract.

2. interface

   Interface defines for all contracts

3. library

   Libraries defines data structure and inline functions

   1. types

      Define data structure for other contracts

   2. typesHelper

      Helper functions for types, the contract use this with: `using typesHelper for types`

   3. other libraries

      Libraries of inline functions

4. vaultSide

   Contracts for `Vault`

5. other contracts

   Main contracts for `settlement layer, or in another word, Ledger`

   Check [conflunce here](https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/279838766/Solidity+Contract+Overview) for more info

# Contract deploy

## Contract information board

https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/343441906/Orderly+V2+Contract+Information+Board

## Ledger scripts

### Deploy command:

```shell
forge script script/ledgerV2/DeployProxyLedger.s.sol -f $RPC_URL_ORDERLYOP --json --broadcast
```

### Upgrade command:

```shell
forge script script/ledgerV2/UpgradeLedger.s.sol -f $RPC_URL_ORDERLYOP --json --broadcast
forge script script/ledgerV2/UpgradeOperatorManager.s.sol -f $RPC_URL_ORDERLYOP --json --broadcast
forge script script/ledgerV2/UpgradeFeeManager.s.sol -f $RPC_URL_ORDERLYOP --json --broadcast
forge script script/ledgerV2/UpgradeVaultManager.s.sol -f $RPC_URL_ORDERLYOP --json --broadcast
forge script script/ledgerV2/UpgradeMarketManager.s.sol -f $RPC_URL_ORDERLYOP --json --broadcast
```

## Vault deploy

### Deploy command:

```shell
forge script script/vaultV2/DeployProxyVault.s.sol -f $RPC_URL_ORDERLYOP --json --broadcast
```

### Upgrade command:

```shell
forge script script/vaultV2/UpgradeVault.s.sol -f $RPC_URL_ORDERLYOP --json --broadcast
```

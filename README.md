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

## CrossChain Setup

## CrossChainRelay Vault Side 43113

1. deploy 0xBfc0B179da8551C8cf62460B93e40071C5ef131D
2. setSrcChainId
3. addCaller(VaultCrossChainManager)
4. addChainIdMapping: native ChianId to Layerzero ChainId
5. setTrustedRemote
6. transfer native token to Contract

## CrossChainRelay Ledger Side 986532

1. deploy 0x2558B46b5a31d0C3d221d9f13f14275eD6C6FdCA
2. setSrcChainId
3. addCaller(LedgerCrossChainManager)
4. addChainIdMapping: native ChianId to Layerzero ChainId
5. setTrustedRemote
6. transfer native token to Contract

### LedgerCrossChainManager

1. deploy 0x095d45c24687e87C6832E8d1C90fa755C16BA382
2. setChainId
3. setLedger
4. setCrossChainRelay
5. setVaultCrossChainManager(chainId, address)

### VaultCrossChainManager

1. deploy 0x4B4E25e461d8Cdc9333196Bc2A27527f3cFc3209
2. setChainId
3. setVault
4. setCrossChainRelay
5. setLedgerCrossChainManager(chainId, address)

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

# CrossChain Manager Upgradeable Deployment and Setup

## prerequiste

- cross-chain relay on target two chains are deployed, address of the relay proxy is put into `.env` file. env variables are `XXX_RELAY_PROXY`, where `XXX` denotes the network name

## Workflow

1. you need to set all common public env variables first

- RPC urls for each network
- chain ids for each network
- private keys for each network

2. set project related env variables

- ledger address
- vault address
- operator manager address
- vault relay address per network
- ledger relay address per network

2. deploy managers
3. setup managers
4. send test tx(ABA) for test manager cross-chain msg sending and receiving

## Deployment or Upgrading

set the following variables in `.env` accordingly:

```shell
# Script Parameters
CURRENT_NETWORK="fuji" # or other network names
CURRENT_SIDE="ledger" # or vault
CALL_METHOD="deploy" # or upgrade
```

and then run the command:

```shell
source .env
# call deploy with vault on the right network
forge script myScript/DeployAndUpgradeManager.s.sol  --rpc-url $RPC_URL_FUJI -vvvv  --via-ir --broadcast
# call deploy with ledger on the right network
forge script myScript/DeployAndUpgradeManager.s.sol  --rpc-url $RPC_URL_ORDERLY -vvvv  --via-ir --broadcast
```

change the `--rpc-url` value to the one suits your instruction.

## Setup

### First setup basic information like chain IDs and other contract address

here is some sample env variables:

```shell
# Script Parameters
CURRENT_NETWORK="fuji" # or other networks
CURRENT_SIDE="vault" # or vault
CALL_METHOD="ledger" # or addVault
LEDGER_NETWORK="orderly"
ADD_VAULT_NETWORK="fuji"
```

then run the command:

```shell
source .env
# call setup
forge script myScript/SetupManager.s.sol --rpc-url $RPC_URL_FUJI -vvvv  --via-ir --broadcast
# call setup
forge script myScript/SetupManager.s.sol --rpc-url $RPC_URL_ORDERLY -vvvv  --via-ir --broadcast
# call addVaultOnLedger
forge script myScript/SetupManager.s.sol --rpc-url $RPC_URL_ORDERLY -vvvv  --via-ir --broadcast
```

## Test

you can set the following variables in `.env` first:

```shell
CURRENT_NETWORK="orderly"
CALL_METHOD="test"
TARGET_NETWORK="fuji"
```

and call to send test withdraw message

```shell
forge script myScript/SetupManager.s.sol --rpc-url $RPC_URL_ORDERLY -vvvv  --via-ir --broadcast
```

later view payload status on layerzeroscan to check whether test succeed.

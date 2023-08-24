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

## Ledger scripts

### Deploy command:

`forge script script/ledger/DeployProxyLedger.s.sol -f $ORDERLY_NETWORK --json --broadcast`

### Upgrade command:

`forge script script/ledger/UpgradeLedger.s.sol -f $ORDERLY_NETWORK --json --broadcast`

`forge script script/ledger/UpgradeOperatorManager.s.sol -f $ORDERLY_NETWORK --json --broadcast`

`forge script script/ledger/UpgradeFeeManager.s.sol -f $ORDERLY_NETWORK --json --broadcast`

`forge script script/ledger/UpgradeVaultManager.s.sol -f $ORDERLY_NETWORK --json --broadcast`

`forge script script/ledger/UpgradeMarketManager.s.sol -f $ORDERLY_NETWORK --json --broadcast`

## Vault deploy

### Deploy command:

`forge script script/vault/DeployProxyVault.s.sol -f $VAULT_NETWORK --json --broadcast`

### Upgrade command:

`forge script script/vault/UpgradeVault.s.sol -f $VAULT_NETWORK --json --broadcast`

### Deposit commond:

`forge script script/vault/StartDeposit.s.sol -f $VAULT_NETWORK --json --broadcast`

## Contract address

### Vault address (Arb goerli testnet)

#### Cross chain

VAULT_CROSS_CHAIN_MANAGER_ADDRESS="0xbc9c21d0986fb7b5ef70caeb16e0abb7c36f1595"

#### Vault

VAULT_PROXY_ADMIN="0x93A5486E16553eb112Ec1Fa41f5B8b9E24102B6e"

TEST_USDC_ADDRESS="0x004d88aa993fd2100d6c8beb6cdb6bc04f565b44"

VAULT_ADDRESS="0x0C554dDb6a9010Ed1FD7e50d92559A06655dA482"

### Ledger address (OP Orderly)

#### Cross chain

LEDGER_CROSS_CHAIN_MANAGER_ADDRESS="0xdecdf6f646d5cfaf16abf12222ccc84febae5934"

#### Ledger

LEDGER_PROXY_ADMIN="0x8910A067473C1800b371183124AEdC95684244DE"

OPERATOR_MANAGER_ADDRESS="0xe34614EB781C5838C78B7f913b89A05e7a5b97e2"

VAULT_MANAGER_ADDRESS="0x4922872C26Befa37AdcA287fF68106013C82FeeD"

LEDGER_ADDRESS="0x8794E7260517B1766fc7b55cAfcd56e6bf08600e"

FEE_MANAGER_ADDRESS="0x835E970110E4a46BCA21A7551FEaA5F532F72701"

MARKET_MANAGER_ADDRESS="0x3ac2Ba11Ca2f9f109d50fb1a46d4C23fCadbbef6"

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

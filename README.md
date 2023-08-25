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

VAULT_CROSS_CHAIN_MANAGER_ADDRESS="0x2266a110c358468e0Fcb173fE77Ce388889483e8"

#### Vault

VAULT_PROXY_ADMIN="0xCaE33d6D72cd2c01b71d6Be3CE2E62b4B7297961"

TEST_USDC_ADDRESS="0x02996B64bf993dd37ABB9e711496813Ec74100a4"

VAULT_ADDRESS="0x22b10472d3Da206aaA85D3f19E91A8da15E0F56A"

### Ledger address (OP Orderly)

#### Cross chain

LEDGER_CROSS_CHAIN_MANAGER_ADDRESS="0x2266a110c358468e0Fcb173fE77Ce388889483e8"

#### Ledger

LEDGER_PROXY_ADMIN="0x0EaC556c0C2321BA25b9DC01e4e3c95aD5CDCd2f"

OPERATOR_MANAGER_ADDRESS="0x7Cd1FBdA284997Be499D3294C9a50352Dd682155"

VAULT_MANAGER_ADDRESS="0x3B092aEe40Cb99174E8C73eF90935F9F35943B22"

LEDGER_ADDRESS="0x50F59504D3623Ad99302835da367676d1f7E3D44"

FEE_MANAGER_ADDRESS="0x8A929891DE9a648B6A3D05d21362418f756cf728"

MARKET_MANAGER_ADDRESS="0x1AFE8286eD1b365671870A735f7deb4dcc9DB16D"

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

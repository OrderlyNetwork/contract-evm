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

### Vault address (Fuji)

#### Cross chain

VAULT_RELAY_ADDRESS="0xc8E38C1Fd1422f49DB592BAe619080EA5Deb50e0"

VAULT_CROSS_CHAIN_MANAGER_ADDRESS="0xC0136Ae389F2AB4b1517c0bF9488Cc13d0546090"

#### Vault

VAULT_PROXY_ADMIN="0x873c120b42C80D528389d85cEA9d4dC0197974aD"

TEST_USDC_ADDRESS="0x1826B75e2ef249173FC735149AE4B8e9ea10abff"

VAULT_ADDRESS="0x523Ab490B15803d6Ba60dC95F1579536F95edD4e"

### Ledger address (Orderly subnet)

#### Cross chain

LEDGER_RELAY_ADDRESS="0x2521750f89bEb11C53a3646D45073bef33312a91"

LEDGER_CROSS_CHAIN_MANAGER_ADDRESS="0xa6814dF691F6fDAD1573cCC5103A712056E1a27c"

#### Ledger

LEDGER_PROXY_ADMIN="0xD9094Ea3AEEEc98af007325d37459E92027D92b4"

OPERATOR_MANAGER_ADDRESS="0x7831C3587388bdC4b037E4F01C82Edd1d4edCA99"

VAULT_MANAGER_ADDRESS="0xEbA7BEf0AF268f60fA572B7FDa286f876Ad44BEb"

LEDGER_ADDRESS="0xB3b86341E796684A7D33Ca102703b85BDE5925b6"

FEE_MANAGER_ADDRESS="0x3bF7fbf5B61DEFC9ee26972AfB1a4A4977b6A2fd"

MARKET_MANAGER_ADDRESS="0x21759c38A7047d73Fe77db5693f12Dc4F51f81Ff"

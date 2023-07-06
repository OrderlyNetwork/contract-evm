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

`forge script myScript/ledger/DeployProxyLedger.s.sol -f $ORDERLY_NETWORK --json --via-ir --broadcast`

### Upgrade command:

`forge script myScript/ledger/UpgradeLedger.s.sol -f $ORDERLY_NETWORK --json --broadcast`

## Vault deploy

### Deploy command:

`forge script myScript/vault/DeployProxyVault.s.sol -f $VAULT_NETWORK --json --broadcast`

### Deposit commond:

`forge script myScript/vault/StartDeposit.s.sol -f $VAULT_NETWORK --json --broadcast`

## Contract address

### Vault address (Fuji)

#### Cross chain

VAULT_RELAY_ADDRESS="0xc8E38C1Fd1422f49DB592BAe619080EA5Deb50e0"

VAULT_CROSS_CHAIN_MANAGER_ADDRESS="0x339c8523d4c2354E392424D76C2c3546Df2e7a13"

#### Vault

VAULT_PROXY_ADMIN="0x873c120b42C80D528389d85cEA9d4dC0197974aD"

TEST_USDC_ADDRESS="0x1826B75e2ef249173FC735149AE4B8e9ea10abff"

VAULT_ADDRESS="0x523Ab490B15803d6Ba60dC95F1579536F95edD4e"

VAULT_IMPL="0x0B98ba78DDb29937d895c718ED167DD8f5B2972d"

### Ledger address (Orderly subnet)

#### Cross chain

LEDGER_RELAY_ADDRESS="0x2521750f89bEb11C53a3646D45073bef33312a91"

LEDGER_CROSS_CHAIN_MANAGER_ADDRESS="0x5771B915a19f1763274Ef97a475C4525dA7F963F"

#### Ledger

LEDGER_PROXY_ADMIN="0xD9094Ea3AEEEc98af007325d37459E92027D92b4"

OPERATOR_MANAGER_ADDRESS="0x7831C3587388bdC4b037E4F01C82Edd1d4edCA99"

VAULT_MANAGER_ADDRESS="0xEbA7BEf0AF268f60fA572B7FDa286f876Ad44BEb"

LEDGER_ADDRESS="0xB3b86341E796684A7D33Ca102703b85BDE5925b6"

FEE_MANAGER_ADDRESS="0x3bF7fbf5B61DEFC9ee26972AfB1a4A4977b6A2fd"

MARKET_MANAGER_ADDRESS="0x21759c38A7047d73Fe77db5693f12Dc4F51f81Ff"

OPERATOR_MANAGER_IMPL="0xeC7ead5354121920459AF511E49E93e0856A06f5"

VAULT_MANAGER_IMPL="0xDD89634c2C4dC6FAF273a454c9Bb8Cde9cBE58b3"

LEDGER_IMPL="0xf1980F824F4890D3E244C37Fcacd0763657c38ca"

FEE_MANAGER_IMPL="0xD650536Be50578e2CFBC0b06CCF8672b043EFEF5"

MARKET_MANAGER_IMPL="0x892fcDEc6E521d7dC84cf05f5cE426AfA4D051c6"

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

## Ledger deploy

command:

`forge script myScript/ledger/DeployProxyLedger.s.sol -f $LEDGER_NETWORK --json --broadcast --legacy`

make sure all the ENV is set:

1. ORDERLY_PRIVATE_KEY
2. OPERATOR_ADDRESS
3. LEDGER_CROSS_CHAIN_MANAGER_ADDRESS
4. LEDGER_NETWORK

## Vault deploy

command:

`forge script myScript/vault/DeployProxyVault.s.sol -f $VAULT_NETWORK --json --broadcast`

`forge script myScript/vault/StartDeposit.s.sol -f $VAULT_NETWORK --json --broadcast`

## Contract address

### Vault address

#### Cross chain

VAULT_RELAY_ADDRESS="0xc8E38C1Fd1422f49DB592BAe619080EA5Deb50e0"

VAULT_CROSS_CHAIN_MANAGER_ADDRESS="0x339c8523d4c2354E392424D76C2c3546Df2e7a13"

#### Vault

VAULT_ADDRESS="0xAbCA777A0439Fc13ff7bA472d85DBb82D83E7738"

TEST_USDC_ADDRESS="0xFc01F6F5E0c6f4c04bB68d0eF4f4e0072748AF21"

### Ledger address

#### Cross chain

LEDGER_RELAY_ADDRESS="0x160aeA20EdB575204849d91F7f3B7c150877a26A"

LEDGER_CROSS_CHAIN_MANAGER_ADDRESS="0x5771B915a19f1763274Ef97a475C4525dA7F963F"

#### Ledger

OPERATOR_MANAGER_ADDRESS="0x4b75a222472d61ed768352ec76be7663057fe88b"

VAULT_MANAGER_ADDRESS="0x1a46be28ab241f5a64f82ddfc384911520e3d557"

LEDGER_ADDRESS="0x873c120b42c80d528389d85cea9d4dc0197974ad"

FEE_MANAGER_ADDRESS="0x1826b75e2ef249173fc735149ae4b8e9ea10abff"

MARKET_MANAGER_ADDRESS="0x0b98ba78ddb29937d895c718ed167dd8f5b2972d"

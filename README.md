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

`forge script myScript/ledger/DeployLedger.s.sol -f $LEDGER_NETWORK --json --broadcast --legacy`

make sure all the ENV is set:

1. ORDERLY_PRIVATE_KEY
2. OPERATOR_ADDRESS
3. LEDGER_CROSS_CHAIN_MANAGER_ADDRESS
4. LEDGER_NETWORK

## Vault deploy

command:

`forge script myScript/vault/DeployVault.s.sol -f $VAULT_NETWORK --json --broadcast`

`forge script myScript/vault/StartDeposit.s.sol -f $VAULT_NETWORK --json --broadcast`

## Contract address

### Vault address

#### Cross chain

VAULT_RELAY_ADDRESS="0xc8E38C1Fd1422f49DB592BAe619080EA5Deb50e0"

VAULT_CROSS_CHAIN_MANAGER_ADDRESS="0x339c8523d4c2354E392424D76C2c3546Df2e7a13"

#### Vault

VAULT_ADDRESS="0x8794E7260517B1766fc7b55cAfcd56e6bf08600e"

TEST_USDC_ADDRESS="0x835E970110E4a46BCA21A7551FEaA5F532F72701"

### Ledger address

#### Cross chain

MUMBAI_LEDGER_RELAY_ADDRESS="0x160aeA20EdB575204849d91F7f3B7c150877a26A"

MUMBAI_LEDGER_CROSS_CHAIN_MANAGER_ADDRESS="0x5771B915a19f1763274Ef97a475C4525dA7F963F"

#### Ledger

OPERATOR_MANAGER_ADDRESS="0x2A5b650A894409372DDeE241EDAC92d4152bE24d"

VAULT_MANAGER_ADDRESS="0xD756A519b8f7B9609Ea61d44804dE79931A0c547"

LEDGER_ADDRESS="0x4307D60DC0EC8817Bc4Ce3751Dc63EC2794d58e2"

FEE_MANAGER_ADDRESS="0x3CAA46F94610BDa1C60267a364d2E154E677BdF9"

MARKET_MANAGER_ADDRESS="0xe34614EB781C5838C78B7f913b89A05e7a5b97e2"

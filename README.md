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

# Contract overview

## Layout

All source code for contracts are inside `src` folder, the script for test is inside `test` folder, the script for deployment is inside `script` folder.

For more information of project structure, please see standard [foundry project layout](https://book.getfoundry.sh/projects/project-layout)

## Src

1. dataLayout

   Complicated dataLayout, or slot storage for contract. The most important data structure is the `userLedger` defined in `LedgerDataLayout.sol`, which is the mapping from accountId (`bytes32` type) to the type `AccountTypes.Account`.

2. interface

   Interface defines for all contracts, including the events, the errors, and the signature of functions.

3. library

   Libraries defines data structure and inline functions.

   1. types

      Define data structure for other contracts, the most import data structure including the `Account` type, `Event` type, `CrossChainMessage` type, etc.

   2. typesHelper

      Helper functions to do different operations on types, the contract use these helper functions with: `using typesHelper for types`

   3. other libraries

      Libraries of inline functions, the `Signature.sol` is used by Ledger contract for the verification of signature from Engine for event upload and trades upload, the `Utils.sol` is used by Vault contract to compute the account id of an Orderly user.

4. vaultSide

   Contracts for `Vault`, including the Vault contract, and a test version of USDC contract. Vault contract is deployed on some EVM-compatiable chain that Orderly supported (e.g. Arbitrum-Goerli), it works as an vault for the user's assets. Users can deposit to or withdraw from Vault contract on some chain they choose.

5. Remaining contracts

   The most important contracts for `settlement layer`, or in another word, the Ledger side. They are `Ledger`, `OperatorManager`, `FeeManager`, `MarketManager`, `VaultManager`. All these contracts are deployed on the Orderly L2 based OP Stack to provide the settlement service for Orderly users.

   On Ledger side, the `Ledger` contract is the main contract to store the user's account information and execute actions according to the function call from `OperatorManager`, and the `OperatorManager` contract is used to receive the operation request from Engine, the `FeeManager` contract is used to manage the fee collector address, the `MarketManager` contract is used to manage the market information for trading context, the `VaultManager` contract is used to manage the token balance of the Vault contract on each EVM chain.

   Check [conflunce here](https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/279838766/Solidity+Contract+Overview) for more info

# Contract deploy

To deploy/upgrade the contracts on Vault and Ledger side, the scripts version 2 under folder `script` is used. The scripts version 1 is deprecated.

Before deployment/upgrading, a suitable `.env` file is needed to be created under the root folder of this repo. The `.env` file should contain the following information:

- RPC URL for each chain, such as RPC_URL_ORDERLYOP, RPC_URL_ARBITRUMGOERLI, etc.
- Private key for the deployer account, such as the ORDERLY_PRIVATE_KEY, ARBITRUM_PRIVATE_KEY, etc.
- Related deployed contract address, such as VAULT_CROSS_CHAIN_MANAGER_ADDRESS, LEDGER_CROSS_CHAIN_MANAGER_ADDRESS, etc.

## Contract information board

The information about deployed contract adress and abi files for each environment is stored in the confluence page:
https://wootraders.atlassian.net/wiki/spaces/ORDER/pages/343441906/Orderly+V2+Contract+Information+Board

## Ledger scripts

### Deploy command:

The contracts on Ledger side is deployed on Orderly L2 based OP Stack, so the rpc is set as RPC_URL_ORDERLYOP. The deploy command is as follows:

```shell
# orderly testnet
forge script script/ledgerV2/DeployProxyLedger.s.sol -f $RPC_URL_ORDERLYOP --broadcast --verifier-url https://testnet-explorer.orderly.org/api\? --verifier blockscout --verify
# orderly mainnet
forge script script/ledgerV2/DeployProxyLedger.s.sol -f $RPC_URL_ORDERLYMAIN --broadcast --verifier-url https://explorer.orderly.network/api\? --verifier blockscout --verify
```

After executing the command, the deployed contracts are Ledger, OperatorManager, FeeManager, MarketManager, and VaultManager. The CrossChainManager is deployed through another repo as mentioned above.

The addresses of the deployed contracts will be listed inside `config` folder, named as `deploy-ledger.json` file.

### Set Cross-Chain Manager

Once the contracts on Ledger side are deployed, the Cross-Chain Manager should be set for Leder contract. The command to set Cross-Chain Manager is as follows:

```shell
# orderly testnet
forge script script/ledgerV2/SetCrossChainManager.s.sol -f $RPC_URL_ORDERLYOP --broadcast
# orderly mainnet
forge script script/ledgerV2/SetCrossChainManager.s.sol -f $RPC_URL_ORDERLYMAIN --broadcast
```

### Upgrade command:

Transparent upgrade pattern is used for contracts on Ledger side, to upgrade a specific contract, the corresponding upgrade script should be executed. The upgrade command is as follows:

```shell
# orderly testnet
forge script script/ledgerV2/UpgradeLedger.s.sol -f $RPC_URL_ORDERLYOP --broadcast --verifier-url https://testnet-explorer.orderly.org/api\? --verifier blockscout --verify
forge script script/ledgerV2/UpgradeOperatorManager.s.sol -f $RPC_URL_ORDERLYOP --broadcast --verifier-url https://testnet-explorer.orderly.org/api\? --verifier blockscout --verify
forge script script/ledgerV2/UpgradeFeeManager.s.sol -f $RPC_URL_ORDERLYOP --broadcast --verifier-url https://testnet-explorer.orderly.org/api\? --verifier blockscout --verify
forge script script/ledgerV2/UpgradeVaultManager.s.sol -f $RPC_URL_ORDERLYOP --broadcast --verifier-url https://testnet-explorer.orderly.org/api\? --verifier blockscout --verify
forge script script/ledgerV2/UpgradeMarketManager.s.sol -f $RPC_URL_ORDERLYOP --broadcast --verifier-url https://testnet-explorer.orderly.org/api\? --verifier blockscout --verify
# orderly mainnet
forge script script/ledgerV2/UpgradeLedger.s.sol -f $RPC_URL_ORDERLYMAIN --broadcast --verifier-url https://explorer.orderly.network/api\? --verifier blockscout --verify
forge script script/ledgerV2/UpgradeOperatorManager.s.sol -f $RPC_URL_ORDERLYMAIN --broadcast --verifier-url https://explorer.orderly.network/api\? --verifier blockscout --verify
forge script script/ledgerV2/UpgradeFeeManager.s.sol -f $RPC_URL_ORDERLYMAIN --broadcast --verifier-url https://explorer.orderly.network/api\? --verifier blockscout --verify
forge script script/ledgerV2/UpgradeVaultManager.s.sol -f $RPC_URL_ORDERLYMAIN --broadcast --verifier-url https://explorer.orderly.network/api\? --verifier blockscout --verify
forge script script/ledgerV2/UpgradeMarketManager.s.sol -f $RPC_URL_ORDERLYMAIN --broadcast --verifier-url https://explorer.orderly.network/api\? --verifier blockscout --verify
```

### Deploy new implement command:

```shell
# orderly testnet
forge script script/ledgerV2/DeployNewLedger.s.sol -f $RPC_URL_ORDERLYOP --broadcast --verifier-url https://testnet-explorer.orderly.org/api\? --verifier blockscout --verify
forge script script/ledgerV2/DeployNewOperatorManager.s.sol -f $RPC_URL_ORDERLYOP --broadcast --verifier-url https://testnet-explorer.orderly.org/api\? --verifier blockscout --verify
forge script script/ledgerV2/DeployNewFeeManager.s.sol -f $RPC_URL_ORDERLYOP --broadcast --verifier-url https://testnet-explorer.orderly.org/api\? --verifier blockscout --verify
forge script script/ledgerV2/DeployNewVaultManager.s.sol -f $RPC_URL_ORDERLYOP --broadcast --verifier-url https://testnet-explorer.orderly.org/api\? --verifier blockscout --verify
forge script script/ledgerV2/DeployNewMarketManager.s.sol -f $RPC_URL_ORDERLYOP --broadcast --verifier-url https://testnet-explorer.orderly.org/api\? --verifier blockscout --verify
forge script script/ledgerV2/DeployNewLedgerImplA.s.sol -f $RPC_URL_ORDERLYOP --broadcast --verifier-url https://testnet-explorer.orderly.org/api\? --verifier blockscout --verify
forge script script/ledgerV2/DeployNewLedgerImplB.s.sol -f $RPC_URL_ORDERLYOP --broadcast --verifier-url https://testnet-explorer.orderly.org/api\? --verifier blockscout --verify
forge script script/ledgerV2/DeployNewLedgerImplC.s.sol -f $RPC_URL_ORDERLYOP --broadcast --verifier-url https://testnet-explorer.orderly.org/api\? --verifier blockscout --verify
forge script script/ledgerV2/DeployNewOperatorManagerImplA.s.sol -f $RPC_URL_ORDERLYOP --broadcast --verifier-url https://testnet-explorer.orderly.org/api\? --verifier blockscout --verify
forge script script/ledgerV2/DeployNewOperatorManagerImplB.s.sol -f $RPC_URL_ORDERLYOP --broadcast --verifier-url https://testnet-explorer.orderly.org/api\? --verifier blockscout --verify
# orderly mainnet
forge script script/ledgerV2/DeployNewLedger.s.sol -f $RPC_URL_ORDERLYMAIN --broadcast --verifier-url https://explorer.orderly.network/api\? --verifier blockscout --verify
forge script script/ledgerV2/DeployNewOperatorManager.s.sol -f $RPC_URL_ORDERLYMAIN --broadcast --verifier-url https://explorer.orderly.network/api\? --verifier blockscout --verify
forge script script/ledgerV2/DeployNewFeeManager.s.sol -f $RPC_URL_ORDERLYMAIN --broadcast --verifier-url https://explorer.orderly.network/api\? --verifier blockscout --verify
forge script script/ledgerV2/DeployNewVaultManager.s.sol -f $RPC_URL_ORDERLYMAIN --broadcast --verifier-url https://explorer.orderly.network/api\? --verifier blockscout --verify
forge script script/ledgerV2/DeployNewMarketManager.s.sol -f $RPC_URL_ORDERLYMAIN --broadcast --verifier-url https://explorer.orderly.network/api\? --verifier blockscout --verify
forge script script/ledgerV2/DeployNewLedgerImplA.s.sol -f $RPC_URL_ORDERLYMAIN --broadcast --verifier-url https://explorer.orderly.network/api\? --verifier blockscout --verify
forge script script/ledgerV2/DeployNewLedgerImplB.s.sol -f $RPC_URL_ORDERLYMAIN --broadcast --verifier-url https://explorer.orderly.network/api\? --verifier blockscout --verify
forge script script/ledgerV2/DeployNewLedgerImplC.s.sol -f $RPC_URL_ORDERLYMAIN --broadcast --verifier-url https://explorer.orderly.network/api\? --verifier blockscout --verify
forge script script/ledgerV2/DeployNewOperatorManagerImplA.s.sol -f $RPC_URL_ORDERLYMAIN --broadcast --verifier-url https://explorer.orderly.network/api\? --verifier blockscout --verify
forge script script/ledgerV2/DeployNewOperatorManagerImplB.s.sol -f $RPC_URL_ORDERLYMAIN --broadcast --verifier-url https://explorer.orderly.network/api\? --verifier blockscout --verify
```

## Vault scripts

The contracts on Vault side is deployed on EVM-compatiable chains, such as Arbitrum-Goerli, so the rpc is set as RPC_URL_ARBITRUMGOERLI.

### Deploy command:

Still the version 2 scripts is used for deployment. The deploy command is as follows:

```shell
# arb sepolia
forge script script/vaultV2/DeployProxyVault.s.sol -f $RPC_URL_ARBITRUMSEPOLIA --verifier-url https://api-sepolia.arbiscan.io/api --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY
# arb mainnet
forge script script/vaultV2/DeployProxyVault.s.sol -f $RPC_URL_ARBITRUM --verifier-url https://api.arbiscan.io/api --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY
# op sepolia
forge script script/vaultV2/DeployProxyVault.s.sol -f $RPC_URL_OPSEPOLIA --verifier-url https://api-sepolia-optimistic.etherscan.io/api --broadcast --verify --etherscan-api-key $OP_ETHERSCAN_API_KEY
# op mainnet
forge script script/vaultV2/DeployProxyVault.s.sol -f $RPC_URL_OP --verifier-url https://api-optimistic.etherscan.io/api --broadcast --verify --etherscan-api-key $OP_ETHERSCAN_API_KEY
# polygon amoy
forge script script/vaultV2/DeployProxyVault.s.sol -f $RPC_URL_POLYGONAMOY --verifier-url https://api-amoy.polygonscan.com/api --broadcast --verify --etherscan-api-key $POLYGON_ETHERSCAN_API_KEY
# polygon mainnet
forge script script/vaultV2/DeployProxyVault.s.sol -f $RPC_URL_POLYGON --verifier-url https://api.polygonscan.com/api --broadcast --verify --etherscan-api-key $POLYGON_ETHERSCAN_API_KEY
# base sepolia
forge script script/vaultV2/DeployProxyVault.s.sol -f $RPC_URL_BASESEPOLIA --verifier-url https://api-sepolia.basescan.org/api --broadcast --verify --etherscan-api-key $BASE_ETHERSCAN_API_KEY
# base mainnet
forge script script/vaultV2/DeployProxyVault.s.sol -f $RPC_URL_BASE --verifier-url https://api.basescan.org/api --broadcast --verify --etherscan-api-key $BASE_ETHERSCAN_API_KEY
# mantle sepolia
forge script script/vaultV2/DeployProxyVault.s.sol -f $RPC_URL_MANTLESEPOLIA --verifier-url https://api-sepolia.mantlescan.xyz/api --broadcast --verify --etherscan-api-key $MANTLE_ETHERSCAN_API_KEY --skip-simulation
# mantle mainnet
forge script script/vaultV2/DeployProxyVault.s.sol -f $RPC_URL_MANTLE --verifier-url https://api.mantlescan.xyz/api --broadcast --verify --etherscan-api-key $MANTLE_ETHERSCAN_API_KEY --skip-simulation
# ethereum sepolia
forge script script/vaultV2/DeployProxyVault.s.sol -f $RPC_URL_SEPOLIA --verifier-url https://api-sepolia.etherscan.io/api --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
# ethereum mainnet
forge script script/vaultV2/DeployProxyVault.s.sol -f $RPC_URL_ETHEREUM --verifier-url https://api.etherscan.io/api --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
# avax fuji
forge script script/vaultV2/DeployProxyVault.s.sol -f $RPC_URL_FUJI --broadcast --verifier-url 'https://api.routescan.io/v2/network/testnet/evm/43113/etherscan' --verify --etherscan-api-key "verifyContract"
# avax mainnet
forge script script/vaultV2/DeployProxyVault.s.sol -f $RPC_URL_AVAX --broadcast --verifier-url 'https://api.routescan.io/v2/network/mainnet/evm/43114/etherscan' --verify --etherscan-api-key "verifyContract"
# sei arctic
forge script script/vaultV2/DeployProxyVault.s.sol -f $RPC_URL_SEIARCTIC --broadcast --legacy
# story test
forge script script/vaultV2/DeployProxyVault.s.sol -f $RPC_URL_STORYODY --broadcast --verifier-url https://testnet.storyscan.xyz/api\? --verifier blockscout
# story mainnet
forge script script/vaultV2/DeployProxyVault.s.sol -f $RPC_URL_STORY --verifier-url https://storyscan.xyz/api\? --verifier blockscout --broadcast
# morph testnet
forge script script/vaultV2/DeployProxyVault.s.sol -f $RPC_URL_MORPHOLESKY --broadcast --verifier-url https://explorer-api-holesky.morphl2.io/api\? --verifier blockscout
# sonic testnet
forge script script/vaultV2/DeployProxyVault.s.sol -f $RPC_URL_SONICTESTNET --broadcast
# morph mainnet
forge script script/vaultV2/DeployProxyVault.s.sol -f $RPC_URL_MORPH --broadcast
# sonic mainnet
forge script script/vaultV2/DeployProxyVault.s.sol -f $RPC_URL_SONIC --broadcast
# berachain mainnet
forge script script/vaultV2/DeployProxyVault.s.sol -f $RPC_URL_BERACHAIN --verifier-url https://api.berascan.com/api --verify --etherscan-api-key $BERACHAIN_ETHERSCAN_API_KEY --broadcast
```

### Deploy new implement command:

```shell
# arb sepolia
forge script script/vaultV2/DeployNewVault.s.sol -f $RPC_URL_ARBITRUMSEPOLIA --verifier-url https://api-sepolia.arbiscan.io/api --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY
# arb mainnet
forge script script/vaultV2/DeployNewVault.s.sol -f $RPC_URL_ARBITRUM --verifier-url https://api.arbiscan.io/api --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY
# op sepolia
forge script script/vaultV2/DeployNewVault.s.sol -f $RPC_URL_OPSEPOLIA --verifier-url https://api-sepolia-optimistic.etherscan.io/api --broadcast --verify --etherscan-api-key $OP_ETHERSCAN_API_KEY
# op mainnet
forge script script/vaultV2/DeployNewVault.s.sol -f $RPC_URL_OP --verifier-url https://api-optimistic.etherscan.io/api --broadcast --verify --etherscan-api-key $OP_ETHERSCAN_API_KEY
# polygon amoy
forge script script/vaultV2/DeployNewVault.s.sol -f $RPC_URL_POLYGONAMOY --verifier-url https://api-amoy.polygonscan.com/api --broadcast --verify --etherscan-api-key $POLYGON_ETHERSCAN_API_KEY
# polygon mainnet
forge script script/vaultV2/DeployNewVault.s.sol -f $RPC_URL_POLYGON --verifier-url https://api.polygonscan.com/api --broadcast --verify --etherscan-api-key $POLYGON_ETHERSCAN_API_KEY
# base sepolia
forge script script/vaultV2/DeployNewVault.s.sol -f $RPC_URL_BASESEPOLIA --verifier-url https://api-sepolia.basescan.org/api --broadcast --verify --etherscan-api-key $BASE_ETHERSCAN_API_KEY
# base mainnet
forge script script/vaultV2/DeployNewVault.s.sol -f $RPC_URL_BASE --verifier-url https://api.basescan.org/api --broadcast --verify --etherscan-api-key $BASE_ETHERSCAN_API_KEY
# mantle sepolia
forge script script/vaultV2/DeployNewVault.s.sol -f $RPC_URL_MANTLESEPOLIA --broadcast --verifier-url https://explorer.sepolia.mantle.xyz/api\? --verifier blockscout --verify --skip-simulation
# mantle mainnet
forge script script/vaultV2/DeployNewVault.s.sol -f $RPC_URL_MANTLE --verifier-url https://api.mantlescan.xyz/api --broadcast --verify --etherscan-api-key $MANTLE_ETHERSCAN_API_KEY --skip-simulation
# sei
forge script script/vaultV2/DeployNewVault.s.sol -f $RPC_URL_SEI --broadcast --legacy
# story test
forge script script/vaultV2/DeployNewVault.s.sol -f $RPC_URL_STORYODY --verifier-url https://testnet.storyscan.xyz/api\? --verifier blockscout --broadcast
# story mainnet
forge script script/vaultV2/DeployNewVault.s.sol -f $RPC_URL_STORY --verifier-url https://storyscan.xyz/api\? --verifier blockscout --broadcast
# morph mainnet
forge script script/vaultV2/DeployNewVault.s.sol -f $RPC_URL_MORPH --broadcast
# sonic mainnet
forge script script/vaultV2/DeployNewVault.s.sol -f $RPC_URL_SONIC --broadcast
# berachain mainnet
forge script script/vaultV2/DeployNewVault.s.sol -f $RPC_URL_BERACHAIN --broadcast
```

## Zip scripts

### Deploy command:

The Zip contract on Ledger side is deployed on Orderly L2 based OP Stack, so the rpc is set as RPC_URL_ORDERLYOP. The deploy command is as follows:

```shell
# orderly testnet
forge script script/zip/DeployProxyZip.s.sol -f $RPC_URL_ORDERLYOP --broadcast --verifier-url https://testnet-explorer.orderly.org/api\? --verifier blockscout --verify
# orderly mainnet
forge script script/zip/DeployProxyZip.s.sol -f $RPC_URL_ORDERLYMAIN --broadcast --verifier-url https://explorer.orderly.network/api\? --verifier blockscout --verify
```

After executing the command, the deployed contracts are Zip proxy contract, Zip implementation contract and the ProxyAdmin contract.

The addresses of the deployed contracts will be listed inside `config` folder, named as `deploy-zip.json` file.

### Set OpearatorManager and Operator Address

Once the contracts are deployed, the Operator EOA address and OperatorManager contract should be set for Zip contract. The command to set is as follows:

```shell
# orderly testnet
forge script script/zip/SetOperatorAddress.s.sol -f $RPC_URL_ORDERLYOP --broadcast
# orderly mainnet
forge script script/zip/SetOperatorAddress.s.sol -f $RPC_URL_ORDERLYMAIN --broadcast
```

### Deploy new implement command:

```shell
# orderly testnet
forge script script/zip/DeployNewZip.s.sol -f $RPC_URL_ORDERLYOP --broadcast --verifier-url https://testnet-explorer.orderly.org/api\? --verifier blockscout --verify
# orderly mainnet
forge script script/zip/DeployNewZip.s.sol -f $RPC_URL_ORDERLYMAIN --broadcast --verifier-url https://explorer.orderly.network/api\? --verifier blockscout --verify
```

### Upgrade command:

Transparent upgrade pattern is used for Zip contract, to upgrade a specific contract, the corresponding upgrade script should be executed. The upgrade command is as follows:

```shell
# orderly testnet
forge script script/zip/UpgradeZip.s.sol -f $RPC_URL_ORDERLYOP --broadcast --verifier-url https://testnet-explorer.orderly.org/api\? --verifier blockscout --verify

# orderly mainnet
forge script script/zip/UpgradeZip.s.sol -f $RPC_URL_ORDERLYMAIN --broadcast --verifier-url https://testnet-explorer.orderly.org/api\? --verifier blockscout --verify
```

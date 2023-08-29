// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "./Utils.sol";

struct LedgerDepolyData {
    address feeManager;
    address ledger;
    address marketManager;
    address operatorManager;
    address proxyAdmin;
    address vaultManager;
}

struct VaultDepolyData {
    address proxyAdmin;
    address tUSDC;
    address vault;
}

struct Envs {
    string env;
    string ledgerNetwork;
    string vaultNetwork;
}

contract ConfigHelper is Script {
    using StringUtils for string;

    string constant ENVS_FILE = "./config/tasks/ledger-vault-envs.json";
    string constant DEPLOY_LEDGER_SAVE_FILE = "./config/deploy-ledger.json";
    string constant DEPLOY_VAULT_SAVE_FILE = "./config/deploy-vault.json";

    function getConfigFileData(string memory envVar) internal returns (bytes memory) {
        string memory configFile = vm.envString(envVar);
        string memory fileData = vm.readFile(configFile);
        bytes memory encodedData = vm.parseJson(fileData);

        vm.closeFile(configFile);

        return encodedData;
    }

    function formKey(string memory key1, string memory key2) internal pure returns (string memory) {
        return key1.formJsonKey().concat(key2.formJsonKey());
    }

    function formKey(string memory key1, string memory key2, string memory key3)
        internal
        pure
        returns (string memory)
    {
        return key1.formJsonKey().concat(key2.formJsonKey().concat(key3.formJsonKey()));
    }

    function getValueByKey(string memory path, string memory key1, string memory key2, string memory key3)
        internal
        view
        returns (bytes memory)
    {
        string memory fileData = vm.readFile(path);
        bytes memory encodedData = vm.parseJson(fileData, formKey(key1, key2, key3));
        return encodedData;
    }

    function getEnvs() internal returns (Envs memory) {
        string memory fileData = vm.readFile(ENVS_FILE);
        vm.closeFile(ENVS_FILE);
        bytes memory encodedData = vm.parseJson(fileData);
        Envs memory envs = abi.decode(encodedData, (Envs));
        return envs;
    }

    function getLedgerDeployData(string memory env, string memory network) internal returns (LedgerDepolyData memory) {
        string memory deployData = vm.readFile(DEPLOY_LEDGER_SAVE_FILE);
        string memory networkKey = env.formJsonKey().concat(network.formJsonKey());
        bytes memory networkEncodeData = vm.parseJson(deployData, networkKey);
        LedgerDepolyData memory networkRelayData = abi.decode(networkEncodeData, (LedgerDepolyData));
        // close file
        vm.closeFile(DEPLOY_LEDGER_SAVE_FILE);
        return networkRelayData;
    }

    function getVaultDeployData(string memory env, string memory network) internal returns (VaultDepolyData memory) {
        string memory deployData = vm.readFile(DEPLOY_VAULT_SAVE_FILE);
        string memory networkKey = env.formJsonKey().concat(network.formJsonKey());
        bytes memory networkEncodeData = vm.parseJson(deployData, networkKey);
        VaultDepolyData memory networkRelayData = abi.decode(networkEncodeData, (VaultDepolyData));
        // close file
        vm.closeFile(DEPLOY_VAULT_SAVE_FILE);
        return networkRelayData;
    }

    function writeLedgerDeployData(string memory env, string memory network, string memory key, string memory value)
        internal
    {
        writeDeployData(env, network, key, value, DEPLOY_LEDGER_SAVE_FILE);
    }

    function writeVaultDeployData(string memory env, string memory network, string memory key, string memory value)
        internal
    {
        writeDeployData(env, network, key, value, DEPLOY_VAULT_SAVE_FILE);
    }

    function writeDeployData(
        string memory env,
        string memory network,
        string memory key,
        string memory value,
        string memory deploySavePath
    ) internal {
        string memory networkKey = env.formJsonKey().concat(network.formJsonKey()).concat(key.formJsonKey());
        vm.writeJson(value, deploySavePath, networkKey);
    }

    function writeToJsonFileByKey(string memory value, string memory path, string memory key1, string memory key2)
        internal
    {
        vm.writeJson(value, path, formKey(key1, key2));
    }

    function writeToJsonFileByKey(
        string memory value,
        string memory path,
        string memory key1,
        string memory key2,
        string memory key3
    ) internal {
        vm.writeJson(value, path, formKey(key1, key2, key3));
    }
}

#!/usr/bin/env ts-node

import { execSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import * as readline from 'readline';
import yargs from 'yargs';
import { hideBin } from 'yargs/helpers';

// Color codes for console output
const colors = {
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
  white: '\x1b[37m',
  reset: '\x1b[0m'
};

interface NetworkConfig {
  name: string;
  chain_id: number;
  rpc_url: string;
  explorer: string;
  explorer_api_url?: string;
  explorer_type?: string;
  usdc?: string;
  usdt?: string;
}

interface ContractInfo {
  [chainName: string]: {
    [contractName: string]: string;
  };
}

interface TokenInfo {
  [tokenName: string]: {
    tokenHash: string;
    decimal: number;
    exceptions?: {
      [chainName: string]: {
        decimal: number;
      };
    };
    depositLimit?: {
      [chainName: string]: string
    };
  };
}

interface LedgerUpgradeConfig {
    ledger: boolean;
    ledgerImplA: boolean;
    ledgerImplB: boolean;
    ledgerImplC: boolean;
    ledgerImplD: boolean;
    operatorManager: boolean;
    operatorManagerImplA: boolean;
    operatorManagerImplB: boolean;
    vaultManager: boolean;
    feeManager: boolean;
}

class VaultChainDeployer {
  private vaultChain: string;
  private ledgerChain: string;
  private safeTasksPath: string;
  private environment: string;
  private networks: Record<string, NetworkConfig> = {};
  private contractInfo: ContractInfo = {};
  private tokens: TokenInfo = {};
  private multisigInfo: any = {};
  private usdtAddress: string = '';

  constructor(vaultChain: string, ledgerChain: string, safeTasksPath: string, environment: string = 'dev') {
    this.vaultChain = vaultChain;
    this.ledgerChain = ledgerChain;
    this.safeTasksPath = safeTasksPath;
    this.environment = environment;
    
    // Load configuration files
    this.loadConfigurations();
  }

  private loadConfigurations() {
    try {
      const contractHelperPath = path.resolve('../contract_helper/contract_info');
      
      // Load networks
      this.networks = JSON.parse(fs.readFileSync(path.join(contractHelperPath, 'networks.json'), 'utf8'));
      
      // Load contract info
      this.contractInfo = JSON.parse(fs.readFileSync(path.join(contractHelperPath, `${this.environment}.json`), 'utf8'));
      
      // Load tokens
      this.tokens = JSON.parse(fs.readFileSync(path.join(contractHelperPath, 'tokens.json'), 'utf8'));
      
      // Load multisig info
      this.multisigInfo = JSON.parse(fs.readFileSync(path.join(contractHelperPath, 'multisig.json'), 'utf8'));
      
      console.log(`${colors.green}✓ Configuration files loaded successfully${colors.reset}`);
    } catch (error) {
      this.exitWithError(`Failed to load configuration files: ${error}`);
    }
  }

  private log(message: string, color: string = colors.reset) {
    console.log(`${color}${message}${colors.reset}`);
  }

  private exitWithError(message: string, command?: string) {
    this.log(`❌ Error: ${message}`, colors.red);
    if (command) {
      this.log(`❌ Failed command: ${command}`, colors.red);
    }
    process.exit(1);
  }

  private runCommand(command: string, retryNum: number = 1, cwd?: string, exitOnError: boolean = true): string {

    while (retryNum > 0) {
      try {
        this.log(`🔄 Running: ${command}`, colors.cyan);
        const result = execSync(command, { 
          encoding: 'utf8', 
          cwd: cwd || process.cwd(),
          stdio: 'pipe'
        });
        return result.trim();
      } catch (error: any) {
        this.log(`⚠️  Command failed: ${error.message}`, colors.yellow);
      }
    }
    retryNum--;
    if (exitOnError) {
      this.exitWithError(`Command failed: ${command}`, command);
    }
    return '';
  }

  private async getUserConfirmation(message: string): Promise<boolean> {
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });

    return new Promise((resolve) => {
      rl.question(`${colors.yellow}${message} (y/N): ${colors.reset}`, (answer) => {
        rl.close();
        resolve(answer.toLowerCase() === 'y' || answer.toLowerCase() === 'yes');
      });
    });
  }

  private async verifyContract(contractAddress: string, chain: string) {
    const network = this.networks[chain];
    if (!network) {
      this.exitWithError(`Network ${chain} not found in configuration`);
    }

    const isEtherscan = network.explorer_type === 'etherscan';
    const verifier = isEtherscan ? 'etherscan' : 'blockscout';

    const verifyCommand = `source .env && forge verify-contract ${contractAddress} -r ${network.rpc_url} --verifier ${verifier} --verifier-url ${network.explorer_api_url} ${isEtherscan ? `--etherscan-api-key $${chain.toUpperCase()}_ETHERSCAN_API_KEY` : ''} --chain-id ${network.chain_id}`;

    this.runCommand(verifyCommand, 1, undefined, false);
  }

  private async upgradeLedgerContract(upgradeConfig: LedgerUpgradeConfig) {
    if (!upgradeConfig.ledger && !upgradeConfig.ledgerImplA && !upgradeConfig.ledgerImplB && !upgradeConfig.ledgerImplC && !upgradeConfig.ledgerImplD && !upgradeConfig.operatorManager && !upgradeConfig.operatorManagerImplA && !upgradeConfig.operatorManagerImplB && !upgradeConfig.vaultManager && !upgradeConfig.feeManager) {
        this.log(`${colors.yellow}   Skipping ledger upgrade because no upgrade config provided.${colors.reset}`);
        return;
    }
    this.log('\n🔧 Pre-requisite: Upgrade Ledger Contract', colors.magenta);

    const ledgerChainInfo = this.contractInfo[this.ledgerChain];
    const ledgerNetwork = this.networks[this.ledgerChain];
    if (!ledgerChainInfo) {
      this.exitWithError(`No contract info found for ${this.ledgerChain}`);
    }

    const isEtherscan = ledgerNetwork.explorer_type === 'etherscan';
    const verifier = isEtherscan ? 'etherscan' : 'blockscout';

    const ledgerDeployCmd= `source .env && forge create src/Ledger.sol:Ledger -r ${ledgerNetwork.rpc_url} --private-key $${this.environment.toUpperCase()}_PK --verifier ${verifier} --verifier-url ${ledgerNetwork.explorer_api_url} ${isEtherscan ? `--etherscan-api-key $${this.ledgerChain.toUpperCase()}_ETHERSCAN_API_KEY --chain-id ${ledgerNetwork.chain_id}` : ''} --broadcast`;

    const ledgerImplADeployCmd = `source .env && forge create src/LedgerImplA.sol:LedgerImplA -r ${ledgerNetwork.rpc_url} --private-key $${this.environment.toUpperCase()}_PK --verifier ${verifier} --verifier-url ${ledgerNetwork.explorer_api_url} ${isEtherscan ? `--etherscan-api-key $${this.ledgerChain.toUpperCase()}_ETHERSCAN_API_KEY --chain-id ${ledgerNetwork.chain_id}` : ''} --broadcast`;

    const ledgerImplBDeployCmd = `source .env && forge create src/LedgerImplB.sol:LedgerImplB -r ${ledgerNetwork.rpc_url} --private-key $${this.environment.toUpperCase()}_PK --verifier ${verifier} --verifier-url ${ledgerNetwork.explorer_api_url} ${isEtherscan ? `--etherscan-api-key $${this.ledgerChain.toUpperCase()}_ETHERSCAN_API_KEY --chain-id ${ledgerNetwork.chain_id}` : ''} --broadcast`;

    const ledgerImplCDeployCmd = `source .env && forge create src/LedgerImplC.sol:LedgerImplC -r ${ledgerNetwork.rpc_url} --private-key $${this.environment.toUpperCase()}_PK --verifier ${verifier} --verifier-url ${ledgerNetwork.explorer_api_url} ${isEtherscan ? `--etherscan-api-key $${this.ledgerChain.toUpperCase()}_ETHERSCAN_API_KEY --chain-id ${ledgerNetwork.chain_id}` : ''} --broadcast`;

    const ledgerImplDDeployCmd = `source .env && forge create src/LedgerImplD.sol:LedgerImplD -r ${ledgerNetwork.rpc_url} --private-key $${this.environment.toUpperCase()}_PK --verifier ${verifier} --verifier-url ${ledgerNetwork.explorer_api_url} ${isEtherscan ? `--etherscan-api-key $${this.ledgerChain.toUpperCase()}_ETHERSCAN_API_KEY --chain-id ${ledgerNetwork.chain_id}` : ''} --broadcast`;

    const operatorManagerDeployCmd = `source .env && forge create src/OperatorManager.sol:OperatorManager -r ${ledgerNetwork.rpc_url} --private-key $${this.environment.toUpperCase()}_PK --verifier ${verifier} --verifier-url ${ledgerNetwork.explorer_api_url} ${isEtherscan ? `--etherscan-api-key $${this.ledgerChain.toUpperCase()}_ETHERSCAN_API_KEY --chain-id ${ledgerNetwork.chain_id}` : ''} --broadcast`;

    const operatorManagerImplADeployCmd = `source .env && forge create src/OperatorManagerImplA.sol:OperatorManagerImplA -r ${ledgerNetwork.rpc_url} --private-key $${this.environment.toUpperCase()}_PK --verifier ${verifier} --verifier-url ${ledgerNetwork.explorer_api_url} ${isEtherscan ? `--etherscan-api-key $${this.ledgerChain.toUpperCase()}_ETHERSCAN_API_KEY --chain-id ${ledgerNetwork.chain_id}` : ''} --broadcast`;

    const operatorManagerImplBDeployCmd = `source .env && forge create src/OperatorManagerImplB.sol:OperatorManagerImplB -r ${ledgerNetwork.rpc_url} --private-key $${this.environment.toUpperCase()}_PK --verifier ${verifier} --verifier-url ${ledgerNetwork.explorer_api_url} ${isEtherscan ? `--etherscan-api-key $${this.ledgerChain.toUpperCase()}_ETHERSCAN_API_KEY --chain-id ${ledgerNetwork.chain_id}` : ''} --broadcast`;

    const vaultManagerDeployCmd = `source .env && forge create src/VaultManager.sol:VaultManager -r ${ledgerNetwork.rpc_url} --private-key $${this.environment.toUpperCase()}_PK --verifier ${verifier} --verifier-url ${ledgerNetwork.explorer_api_url} ${isEtherscan ? `--etherscan-api-key $${this.ledgerChain.toUpperCase()}_ETHERSCAN_API_KEY --chain-id ${ledgerNetwork.chain_id}` : ''} --broadcast`;

    const feeManagerDeployCmd = `source .env && forge create src/FeeManager.sol:FeeManager -r ${ledgerNetwork.rpc_url} --private-key $${this.environment.toUpperCase()}_PK --verifier ${verifier} --verifier-url ${ledgerNetwork.explorer_api_url} ${isEtherscan ? `--etherscan-api-key $${this.ledgerChain.toUpperCase()}_ETHERSCAN_API_KEY --chain-id ${ledgerNetwork.chain_id}` : ''} --broadcast`;

    const ledgerDeployOutput = upgradeConfig.ledger ? this.runCommand(ledgerDeployCmd) : '';
    const ledgerImplADeployOutput = upgradeConfig.ledgerImplA ? this.runCommand(ledgerImplADeployCmd) : '';
    const ledgerImplBDeployOutput = upgradeConfig.ledgerImplB ? this.runCommand(ledgerImplBDeployCmd) : '';
    const ledgerImplCDeployOutput = upgradeConfig.ledgerImplC ? this.runCommand(ledgerImplCDeployCmd) : '';
    const ledgerImplDDeployOutput = upgradeConfig.ledgerImplD ? this.runCommand(ledgerImplDDeployCmd) : '';

    const operatorManagerDeployOutput = upgradeConfig.operatorManager ? this.runCommand(operatorManagerDeployCmd) : '';
    const operatorManagerImplADeployOutput = upgradeConfig.operatorManagerImplA ? this.runCommand(operatorManagerImplADeployCmd) : '';
    const operatorManagerImplBDeployOutput = upgradeConfig.operatorManagerImplB ? this.runCommand(operatorManagerImplBDeployCmd) : '';

    const vaultManagerDeployOutput = upgradeConfig.vaultManager ? this.runCommand(vaultManagerDeployCmd) : '';
    const feeManagerDeployOutput = upgradeConfig.feeManager ? this.runCommand(feeManagerDeployCmd) : '';

    const deployedToMatch = ledgerDeployOutput.match(/Deployed to: (0x[a-fA-F0-9]{40})/);
    const deployedToMatchImplA = ledgerImplADeployOutput.match(/Deployed to: (0x[a-fA-F0-9]{40})/);
    const deployedToMatchImplB = ledgerImplBDeployOutput.match(/Deployed to: (0x[a-fA-F0-9]{40})/);
    const deployedToMatchImplC = ledgerImplCDeployOutput.match(/Deployed to: (0x[a-fA-F0-9]{40})/);
    const deployedToMatchImplD = ledgerImplDDeployOutput.match(/Deployed to: (0x[a-fA-F0-9]{40})/);

    const deployedToMatchOperatorManager = operatorManagerDeployOutput.match(/Deployed to: (0x[a-fA-F0-9]{40})/);
    const deployedToMatchOperatorManagerImplA = operatorManagerImplADeployOutput.match(/Deployed to: (0x[a-fA-F0-9]{40})/);
    const deployedToMatchOperatorManagerImplB = operatorManagerImplBDeployOutput.match(/Deployed to: (0x[a-fA-F0-9]{40})/);

    const deployedToMatchVaultManager = vaultManagerDeployOutput.match(/Deployed to: (0x[a-fA-F0-9]{40})/);

    const deployedToMatchFeeManager = feeManagerDeployOutput.match(/Deployed to: (0x[a-fA-F0-9]{40})/);

    const newLedgerAddress = deployedToMatch?.[1];
    const newLedgerImplAAddress = deployedToMatchImplA?.[1];
    const newLedgerImplBAddress = deployedToMatchImplB?.[1];
    const newLedgerImplCAddress = deployedToMatchImplC?.[1];
    const newLedgerImplDAddress = deployedToMatchImplD?.[1];

    const newOperatorManagerAddress = deployedToMatchOperatorManager?.[1];
    const newOperatorManagerImplAAddress = deployedToMatchOperatorManagerImplA?.[1];
    const newOperatorManagerImplBAddress = deployedToMatchOperatorManagerImplB?.[1];

    const newVaultManagerAddress = deployedToMatchVaultManager?.[1];
    const newFeeManagerAddress = deployedToMatchFeeManager?.[1];


    if (upgradeConfig.ledger) {
        if (!newLedgerAddress) {
            this.exitWithError('Failed to extract deployed contract address from output');
            return ''; // This will never be reached due to process.exit in exitWithError
        }
        await this.verifyContract(newLedgerAddress, this.ledgerChain);
    }
    if (upgradeConfig.ledgerImplA) {
        if (!newLedgerImplAAddress) {
            this.exitWithError('Failed to extract deployed contract address from output');
            return ''; // This will never be reached due to process.exit in exitWithError
        }
        await this.verifyContract(newLedgerImplAAddress, this.ledgerChain);
    }
    if (upgradeConfig.ledgerImplB) {
        if (!newLedgerImplBAddress) {
            this.exitWithError('Failed to extract deployed contract address from output');
            return ''; // This will never be reached due to process.exit in exitWithError
        }
        await this.verifyContract(newLedgerImplBAddress, this.ledgerChain);
    }
    if (upgradeConfig.ledgerImplC) {
        if (!newLedgerImplCAddress) {
            this.exitWithError('Failed to extract deployed contract address from output');
            return ''; // This will never be reached due to process.exit in exitWithError
        }
        await this.verifyContract(newLedgerImplCAddress, this.ledgerChain);
    }
    if (upgradeConfig.ledgerImplD) {
        if (!newLedgerImplDAddress) {
            this.exitWithError('Failed to extract deployed contract address from output');
            return ''; // This will never be reached due to process.exit in exitWithError
        }
        await this.verifyContract(newLedgerImplDAddress, this.ledgerChain);
    }
    if (upgradeConfig.operatorManager) {
        if (!newOperatorManagerAddress) {
            this.exitWithError('Failed to extract deployed contract address from output');
            return ''; // This will never be reached due to process.exit in exitWithError
        }
        await this.verifyContract(newOperatorManagerAddress, this.ledgerChain);
    }
    if (upgradeConfig.operatorManagerImplA) {
        if (!newOperatorManagerImplAAddress) {
            this.exitWithError('Failed to extract deployed contract address from output');
            return ''; // This will never be reached due to process.exit in exitWithError   
        }
        await this.verifyContract(newOperatorManagerImplAAddress, this.ledgerChain);
    }
    if (upgradeConfig.operatorManagerImplB) {
        if (!newOperatorManagerImplBAddress) {
            this.exitWithError('Failed to extract deployed contract address from output');
            return ''; // This will never be reached due to process.exit in exitWithError
        }
        await this.verifyContract(newOperatorManagerImplBAddress, this.ledgerChain);
    }
    if (upgradeConfig.vaultManager) {
        if (!newVaultManagerAddress) {
            this.exitWithError('Failed to extract deployed contract address from output');
            return ''; // This will never be reached due to process.exit in exitWithError
        }
        await this.verifyContract(newVaultManagerAddress, this.ledgerChain);
    }
    if (upgradeConfig.feeManager) {
        if (!newFeeManagerAddress) {
            this.exitWithError('Failed to extract deployed contract address from output');
            return ''; // This will never be reached due to process.exit in exitWithError
        }
        await this.verifyContract(newFeeManagerAddress, this.ledgerChain);
    }

    const proposals = [];

    const ledgerUpgradeProposal = {
      "_description": `Upgrade ledger contract`,
      "to": ledgerChainInfo.ledgerProxyAdmin,
      "value": "0",
      "method": "upgrade(address, address)",
      "params": [
        ledgerChainInfo.ledger,
        newLedgerAddress
      ],
      "operation": 0
    };
    if (upgradeConfig.ledger) { proposals.push(ledgerUpgradeProposal); }
    const setLedgerImplAProposal = {
      "_description": `set ledger impl A contract`,
      "to": ledgerChainInfo.ledger,
      "value": "0",
      "method": "setLedgerImplA(address)",
      "params": [
        newLedgerImplAAddress
      ],
      "operation": 0
    };
    if (upgradeConfig.ledgerImplA) { proposals.push(setLedgerImplAProposal); }
    const setLedgerImplBProposal = {
      "_description": `set ledger impl B contract`,
      "to": ledgerChainInfo.ledger,
      "value": "0",
      "method": "setLedgerImplB(address)",
      "params": [
        newLedgerImplBAddress
      ],
      "operation": 0
    };
    if (upgradeConfig.ledgerImplB) { proposals.push(setLedgerImplBProposal); }
    const setLedgerImplCProposal = {
      "_description": `set ledger impl C contract`,
      "to": ledgerChainInfo.ledger,
      "value": "0",
      "method": "setLedgerImplC(address)",
      "params": [
        newLedgerImplCAddress
      ],
      "operation": 0
    };
    if (upgradeConfig.ledgerImplC) { proposals.push(setLedgerImplCProposal); }
    const setLedgerImplDProposal = {
      "_description": `set ledger impl D contract`,
      "to": ledgerChainInfo.ledger,
      "value": "0",
      "method": "setLedgerImplD(address)",
      "params": [
        newLedgerImplDAddress
      ],
      "operation": 0
    };
    if (upgradeConfig.ledgerImplD) { proposals.push(setLedgerImplDProposal); }
    const upgradeOperatorManagerProposal = {
      "_description": `Upgrade operator manager contract`,
      "to": ledgerChainInfo.ledgerProxyAdmin,
      "value": "0",
      "method": "upgrade(address, address)",
      "params": [
        ledgerChainInfo.operatorManager,
        newOperatorManagerAddress
      ],
      "operation": 0
    };
    if (upgradeConfig.operatorManager) { proposals.push(upgradeOperatorManagerProposal); }
    const setOperatorManagerImplAProposal = {
      "_description": `set operator manager impl A contract`,
      "to": ledgerChainInfo.operatorManager,
      "value": "0",
      "method": "setOperatorManagerImplA(address)",
      "params": [
        newOperatorManagerImplAAddress
      ],
      "operation": 0
    };
    if (upgradeConfig.operatorManagerImplA) { proposals.push(setOperatorManagerImplAProposal); }
    const setOperatorManagerImplBProposal = {
      "_description": `set operator manager impl B contract`,
      "to": ledgerChainInfo.operatorManager,
      "value": "0",
      "method": "setOperatorManagerImplB(address)",
      "params": [
        newOperatorManagerImplBAddress
      ],
      "operation": 0
    };
    if (upgradeConfig.operatorManagerImplB) { proposals.push(setOperatorManagerImplBProposal); }
    const upgradeVaultManagerProposal = {
      "_description": `Upgrade vault manager contract`,
      "to": ledgerChainInfo.ledgerProxyAdmin,
      "value": "0",
      "method": "upgrade(address, address)",
      "params": [
        ledgerChainInfo.vaultManager,
        newVaultManagerAddress
      ],
      "operation": 0
    };
    const upgradeFeeManagerProposal = {
      "_description": `Upgrade fee manager contract`,
      "to": ledgerChainInfo.ledgerProxyAdmin,
      "value": "0",
      "method": "upgrade(address, address)",
      "params": [
        ledgerChainInfo.feeManager,
        newFeeManagerAddress
      ],
      "operation": 0
    };
    if (upgradeConfig.feeManager) { proposals.push(upgradeFeeManagerProposal); }
    if (upgradeConfig.vaultManager && this.environment !== 'dev') { proposals.push(upgradeVaultManagerProposal); }
    if (this.environment === 'dev') {
        this.log(`${colors.yellow}   Skipping vault manager upgrade in dev environment, deploy it manually because of storage slot issue.${colors.reset}`);
    }

    const proposalPath = path.join(this.safeTasksPath, `upgrade-ledger-${this.ledgerChain}-${Date.now()}.json`);
    fs.writeFileSync(proposalPath, JSON.stringify(proposals, null, 2));

    this.log(`📝 Upgrade proposal created: ${proposalPath}`, colors.blue);

    // Submit proposal
    const proposeCommand = `yarn safe propose-multi --network ${this.ledgerChain.toLocaleLowerCase()} --env ${this.environment} ${proposalPath}`;
    const proposeOutput = this.runCommand(proposeCommand, 3, this.safeTasksPath);

    // Extract safe transaction hash
    const safeHashMatch = proposeOutput.match(/Safe transaction hash: (0x[a-fA-F0-9]{64})/);
    if (!safeHashMatch) {
      this.exitWithError('Failed to extract Safe transaction hash from propose output');
      return ''; // This will never be reached due to process.exit in exitWithError
    }

    const safeTransactionHash = safeHashMatch[1];
    this.log(`✅ Upgrade proposal created: ${safeTransactionHash}`, colors.green);

    return safeTransactionHash;
  }

  private async deployUSDT(): Promise<string> {
    this.log('\n🚀 Pre-requisite: Deploying USDT Contract', colors.magenta);

    const network = this.networks[this.vaultChain];
    if (!network) {
      this.exitWithError(`Network ${this.vaultChain} not found in configuration`);
    }

    const getTokenDecimal = (token: any, chainName: string) => {
      return token.exceptions?.[chainName]?.decimal || token.decimal;
    };

    const usdtToken = this.tokens.usdt;
    const usdtDecimal = getTokenDecimal(usdtToken, this.vaultChain);
    const isEtherscan = network.explorer_type === 'etherscan';
    const verifier = isEtherscan ? 'etherscan' : 'blockscout';

    const deployCommand = `source .env && forge create test/utils/TestERC20.sol:TestERC20 -r ${network.rpc_url} --private-key $${this.environment.toUpperCase()}_PK --verifier ${verifier} --verifier-url ${network.explorer_api_url} ${isEtherscan ? `--etherscan-api-key $${this.vaultChain.toUpperCase()}_ETHERSCAN_API_KEY` : ''} --chain-id ${network.chain_id} --broadcast --constructor-args ${usdtToken.tokenHash} ${usdtDecimal} tUSDT tUSDT ${usdtDecimal}`;

    const output = this.runCommand(deployCommand);

    const deployedToMatch = output.match(/Deployed to: (0x[a-fA-F0-9]{40})/);
    const txHashMatch = output.match(/Transaction hash: (0x[a-fA-F0-9]{64})/);
    const deployerMatch = output.match(/Deployer: (0x[a-fA-F0-9]{40})/);

    if (!deployedToMatch) {
      this.exitWithError('Failed to extract deployed contract address from output');
      return ''; // This will never be reached due to process.exit in exitWithError
    }

    const contractAddress = deployedToMatch[1];
    const txHash = txHashMatch?.[1] || 'N/A';
    const deployer = deployerMatch?.[1] || 'N/A';

    await this.verifyContract(contractAddress, this.vaultChain);

    this.log(`✅ USDT deployed successfully!`, colors.green);
    this.log(`   Deployer: ${deployer}`, colors.blue);
    this.log(`   Contract Address: ${contractAddress}`, colors.blue);
    this.log(`   Transaction Hash: ${txHash}`, colors.blue);

    return contractAddress;
  }

  private async deployVaultContract(deployUsdt: boolean = false): Promise<string> {

    if (deployUsdt) {
      const usdtAddress = await this.deployUSDT();
      this.usdtAddress = usdtAddress;
    }

    this.log('\n🚀 Step 1: Deploying Vault Contract', colors.magenta);

    const network = this.networks[this.vaultChain];
    if (!network) {
      this.exitWithError(`Network ${this.vaultChain} not found in configuration`);
    }

    // Check if explorer is etherscan or blockscout based on URL
    const isEtherscan = network.explorer_type === 'etherscan';
    const verifier = isEtherscan ? 'etherscan' : 'blockscout';

    const deployCommand = `source .env && forge create src/vaultSide/Vault.sol:Vault -r ${network.rpc_url} --private-key $${this.environment.toUpperCase()}_PK --verifier ${verifier} --verifier-url ${network.explorer_api_url} ${isEtherscan ? `--etherscan-api-key $${this.vaultChain.toUpperCase()}_ETHERSCAN_API_KEY` : ''} --chain-id ${network.chain_id} --broadcast --delay 10`;


    const output = this.runCommand(deployCommand);
    
    // Parse deployment output to extract contract address
    const deployedToMatch = output.match(/Deployed to: (0x[a-fA-F0-9]{40})/);
    const txHashMatch = output.match(/Transaction hash: (0x[a-fA-F0-9]{64})/);
    const deployerMatch = output.match(/Deployer: (0x[a-fA-F0-9]{40})/);

    if (!deployedToMatch) {
      this.exitWithError('Failed to extract deployed contract address from output');
      return ''; // This will never be reached due to process.exit in exitWithError
    }

    await this.verifyContract(deployedToMatch[1], this.vaultChain);

    const contractAddress = deployedToMatch[1];
    const txHash = txHashMatch?.[1] || 'N/A';
    const deployer = deployerMatch?.[1] || 'N/A';

    this.log(`✅ Vault deployed successfully!`, colors.green);
    this.log(`   Deployer: ${deployer}`, colors.blue);
    this.log(`   Contract Address: ${contractAddress}`, colors.blue);
    this.log(`   Transaction Hash: ${txHash}`, colors.blue);

    return contractAddress;
  }

  private async upgradeVaultContract(contractAddress: string): Promise<string> {
    this.log('\n🔧 Step 2: Creating Upgrade Proposal', colors.magenta);

    const vaultChainInfo = this.contractInfo[this.vaultChain];
    if (!vaultChainInfo) {
      this.exitWithError(`No contract info found for ${this.vaultChain}`);
    }

    const proxyAdmin = vaultChainInfo.vaultProxyAdmin;
    const proxyAddress = vaultChainInfo.vault;

    if (!proxyAdmin || !proxyAddress) {
      this.exitWithError(`Missing proxyAdmin or vault proxy address for ${this.vaultChain}`);
    }

    // Create upgrade proposal JSON
    const upgradeProposal = [{
      "_description": `Upgrade vault contract, to: ProxyAdmin, param1: Proxy, param2: Implementation`,
      "to": proxyAdmin,
      "value": "0",
      "method": "upgrade(address,address)",
      "params": [
        proxyAddress,
        contractAddress
      ],
      "operation": 0
    }];

    const proposalPath = path.join(this.safeTasksPath, `upgrade-vault-${this.vaultChain}-${Date.now()}.json`);
    fs.writeFileSync(proposalPath, JSON.stringify(upgradeProposal, null, 2));

    this.log(`📝 Upgrade proposal created: ${proposalPath}`, colors.blue);

    // Submit proposal
    const proposeCommand = `yarn safe propose-multi --network ${this.vaultChain.toLocaleLowerCase()} --env ${this.environment} ${proposalPath}`;
    const proposeOutput = this.runCommand(proposeCommand, 3, this.safeTasksPath);

    // Extract safe transaction hash
    const safeHashMatch = proposeOutput.match(/Safe transaction hash: (0x[a-fA-F0-9]{64})/);
    if (!safeHashMatch) {
      this.exitWithError('Failed to extract Safe transaction hash from propose output');
      return ''; // This will never be reached due to process.exit in exitWithError
    }

    const safeTransactionHash = safeHashMatch[1];
    this.log(`✅ Upgrade proposal created: ${safeTransactionHash}`, colors.green);

    return safeTransactionHash;
  }

  private async signAndSubmitProposal(chain: string, safeTransactionHash: string, description: string) {
    this.log(`\n✍️ Signing and submitting ${description}`, colors.magenta);

    // Sign proposal (without --sync-sig)
    const signCommand = `yarn safe sign-proposal --network ${chain.toLocaleLowerCase()} ${safeTransactionHash}`;
    this.runCommand(signCommand, 3, this.safeTasksPath);
    this.log(`✅ Proposal signed`, colors.green);

    // Submit proposal (without --collect-sig)
    const submitCommand = `yarn safe submit-proposal --network ${chain.toLocaleLowerCase()} ${safeTransactionHash}`;
    this.runCommand(submitCommand, 3, this.safeTasksPath);
    this.log(`✅ Proposal submitted and executed`, colors.green);
  }

  private async setupVault(): Promise<string> {
    this.log('\n⚙️ Step 3: Setting up Vault (Multicollateral Setup)', colors.magenta);

    const vaultChainInfo = this.contractInfo[this.vaultChain];
    const vaultAddress = vaultChainInfo.vault;
    const network = this.networks[this.vaultChain];

    // Get token information
    const usdtToken = this.tokens.usdt;
    const ethToken = this.tokens.eth;
    const usdcToken = this.tokens.usdc;

    // Get token decimals for this chain
    const getTokenDecimal = (token: any, chainName: string) => {
      return token.exceptions?.[chainName]?.decimal || token.decimal;
    };

    const usdtDecimal = getTokenDecimal(usdtToken, this.vaultChain);
    const ethDecimal = getTokenDecimal(ethToken, this.vaultChain);

    // warning if usdtAddress is not set
    if (!this.usdtAddress && !network.usdt) {
      this.log(`⚠️ Warning: USDT address is not set, using placeholder address`, colors.yellow);
    }

    // Create vault setup proposal
    const vaultSetupProposal = [
      {
        "_description": "Enable USDT Token Hash and Set Token Address",
        "to": vaultAddress,
        "value": "0",
        "method": "changeTokenAddressAndAllow(bytes32,address)",
        "params": [
          usdtToken.tokenHash,
          network.usdt || this.usdtAddress || '0x0000000000000000000000000000000000000000'
        ],
        "operation": 0
      },
      {
        "_description": "Set Native ETH Token Hash",
        "to": vaultAddress,
        "value": "0",
        "method": "setNativeTokenHash(bytes32)",
        "params": [
          ethToken.tokenHash
        ],
        "operation": 0
      },
      {
        "_description": "Enable Native ETH Token Hash",
        "to": vaultAddress,
        "value": "0",
        "method": "setAllowedToken(bytes32,bool)",
        "params": [
          ethToken.tokenHash,
          true
        ],
        "operation": 0
      },
      {
        "_description": "Enable USDC Rebalance",
        "to": vaultAddress,
        "value": "0",
        "method": "setRebalanceEnableToken(bytes32,bool)",
        "params": [
          usdcToken.tokenHash,
          true
        ],
        "operation": 0
      },
      {
        "_description": "Set Swap Signer Address",
        "to": vaultAddress,
        "value": "0",
        "method": "setSwapSigner(address)",
        "params": [
            vaultChainInfo.operator
        ],
        "operation": 0
      },
      {
        "_description": "Set Swap Operator Address",
        "to": vaultAddress,
        "value": "0",
        "method": "setSwapOperator(address)",
        "params": [
            vaultChainInfo.operator
        ],
        "operation": 0
      }
    ];

    if (usdtToken.depositLimit && usdtToken.depositLimit[this.vaultChain]) {
      vaultSetupProposal.push({
        "_description": "Set USDT Deposit Limit",
        "to": vaultAddress,
        "value": "0",
        "method": "setDepositLimit(uint256)",
        "params": [
          usdtToken.depositLimit[this.vaultChain].replace(/_/g, '')
        ],
        "operation": 0
      });
    }

    if (ethToken.depositLimit && ethToken.depositLimit[this.vaultChain]) {
      vaultSetupProposal.push({
        "_description": "Set ETH Deposit Limit",
        "to": vaultAddress,
        "value": "0",
        "method": "setNativeTokenDepositLimit(uint256)",
        "params": [
          ethToken.depositLimit[this.vaultChain].replace(/_/g, '')
        ],
        "operation": 0
      });
    }

    const proposalPath = path.join(this.safeTasksPath, `setup-vault-${this.vaultChain}-${Date.now()}.json`);
    fs.writeFileSync(proposalPath, JSON.stringify(vaultSetupProposal, null, 2));

    this.log(`📝 Vault setup proposal created: ${proposalPath}`, colors.blue);

    // Submit proposal
    const proposeCommand = `yarn safe propose-multi --network ${this.vaultChain.toLocaleLowerCase()} --env ${this.environment} ${proposalPath}`;
    const proposeOutput = this.runCommand(proposeCommand, 3, this.safeTasksPath);

    // Extract safe transaction hash
    const safeHashMatch = proposeOutput.match(/Safe transaction hash: (0x[a-fA-F0-9]{64})/);
    if (!safeHashMatch) {
      this.exitWithError('Failed to extract Safe transaction hash from vault setup propose output');
      return ''; // This will never be reached due to process.exit in exitWithError
    }

    const safeTransactionHash = safeHashMatch[1];
    this.log(`✅ Vault setup proposal created: ${safeTransactionHash}`, colors.green);

    return safeTransactionHash;
  }

  private async setupLedger(isFirstTime: boolean = false): Promise<string> {
    this.log('\n⚙️ Step 4: Setting up Ledger (Multicollateral Setup)', colors.magenta);

    const ledgerChainInfo = this.contractInfo[this.ledgerChain];
    const vaultManager = ledgerChainInfo.vaultManager;
    const ledgerCCManager = ledgerChainInfo.ledgerCCManager;
    const vaultChainId = this.networks[this.vaultChain].chain_id;
    const ledgerChainId = this.networks[this.ledgerChain].chain_id;

    // Get token information
    const usdtToken = this.tokens.usdt;
    const ethToken = this.tokens.eth;

    // Get token decimals for both chains
    const getTokenDecimal = (token: any, chainName: string) => {
      return token.exception?.[chainName]?.decimals || token.decimals;
    };

    const usdtVaultChainDecimal = getTokenDecimal(usdtToken, this.vaultChain);
    const ethVaultChainDecimal = getTokenDecimal(ethToken, this.vaultChain);
    const usdtLedgerChainDecimal = getTokenDecimal(usdtToken, this.ledgerChain);
    const ethLedgerChainDecimal = getTokenDecimal(ethToken, this.ledgerChain);

    const ledgerSetupProposal = [];

    if (isFirstTime) {
      ledgerSetupProposal.push({
        "_description": "Set allowed token in VaultManager",
        "to": vaultManager,
        "value": "0",
        "method": "setAllowedToken(bytes32,bool)",
        "params": [
          ethToken.tokenHash,
          true
        ],
        "operation": 0
      });
      ledgerSetupProposal.push({
        "_description": "Set allowed token in VaultManager",
        "to": vaultManager,
        "value": "0",
        "method": "setAllowedToken(bytes32,bool)",
        "params": [
          usdtToken.tokenHash,
          true
        ],
        "operation": 0
      });
      ledgerSetupProposal.push({
        "_description": "Set token decimal of ETH in Ledger Chain on Ledger CC Manager",
        "to": ledgerCCManager,
        "value": "0",
        "method": "setTokenDecimal(bytes32,uint256,uint128)",
        "params": [
          ethToken.tokenHash,
          ledgerChainId,
          ethLedgerChainDecimal
        ],
        "operation": 0
      });
      ledgerSetupProposal.push({
        "_description": "Set token decimal of USDT in Ledger Chain on Ledger CC Manager",
        "to": ledgerCCManager,
        "value": "0",
        "method": "setTokenDecimal(bytes32,uint256,uint128)",
        "params": [
          usdtToken.tokenHash,
          ledgerChainId,
          usdtLedgerChainDecimal
        ],
        "operation": 0
      });
    }

    // Create ledger setup proposal
    const ledgerSetupProposal2 = [
      {
        "_description": "Set allowed token in VaultManager",
        "to": vaultManager,
        "value": "0",
        "method": "setAllowedChainToken(bytes32,uint256,bool)",
        "params": [
          ethToken.tokenHash,
          vaultChainId,
          true
        ],
        "operation": 0
      },
      {
        "_description": "Set allowed chain token in VaultManager",
        "to": vaultManager,
        "value": "0",
        "method": "setAllowedChainToken(bytes32,uint256,bool)",
        "params": [
          usdtToken.tokenHash,
          vaultChainId,
          true
        ],
        "operation": 0
      },
      {
        "_description": "Set token decimal of USDT in Vault Chain on Ledger CC Manager",
        "to": ledgerCCManager,
        "value": "0",
        "method": "setTokenDecimal(bytes32,uint256,uint128)",
        "params": [
          usdtToken.tokenHash,
          vaultChainId,
          usdtVaultChainDecimal
        ],
        "operation": 0
      },
      {
        "_description": "Set token decimal of ETH in Vault Chain on Ledger CC Manager",
        "to": ledgerCCManager,
        "value": "0",
        "method": "setTokenDecimal(bytes32,uint256,uint128)",
        "params": [
          ethToken.tokenHash,
          vaultChainId,
          ethVaultChainDecimal
        ],
        "operation": 0
      }
    ];

    const ledgerSetupProposal3 = [
      {
        "_description": "Set Protocol Vault Address in VaultManager",
        "to": vaultManager,
        "value": "0",
        "method": "setProtocolVaultAddress(address)",
        "params": [
          "0x0000000000000000000000000000000000000000"
        ],
        "operation": 0
      }
    ]

    ledgerSetupProposal.push(...ledgerSetupProposal2);
    ledgerSetupProposal.push(...ledgerSetupProposal3);

    const proposalPath = path.join(this.safeTasksPath, `setup-ledger-${this.ledgerChain}-${Date.now()}.json`);
    fs.writeFileSync(proposalPath, JSON.stringify(ledgerSetupProposal, null, 2));

    this.log(`📝 Ledger setup proposal created: ${proposalPath}`, colors.blue);

    // Submit proposal
    const proposeCommand = `yarn safe propose-multi --network ${this.ledgerChain.toLocaleLowerCase()} --env ${this.environment} ${proposalPath}`;
    const proposeOutput = this.runCommand(proposeCommand, 3, this.safeTasksPath);

    // Extract safe transaction hash
    const safeHashMatch = proposeOutput.match(/Safe transaction hash: (0x[a-fA-F0-9]{64})/);
    if (!safeHashMatch) {
      this.exitWithError('Failed to extract Safe transaction hash from ledger setup propose output');
      return ''; // This will never be reached due to process.exit in exitWithError
    }

    const safeTransactionHash = safeHashMatch[1];
    this.log(`✅ Ledger setup proposal created: ${safeTransactionHash}`, colors.green);

    return safeTransactionHash;
  }

  private async checkContractConfig() {
    this.log('\n🔍 Step 5: Checking Contract Configuration', colors.magenta);

    const vaultChainInfo = this.contractInfo[this.vaultChain];
    const ledgerChainInfo = this.contractInfo[this.ledgerChain];
    const vaultAddress = vaultChainInfo.vault;
    const vaultManager = ledgerChainInfo.vaultManager;
    const network = this.networks[this.vaultChain];
    const ledgerNetwork = this.networks[this.ledgerChain];

    this.log('\n📊 Vault Contract Configuration:', colors.cyan);

    try {
      // Check vault configuration
      const nativeTokenHash = this.runCommand(`cast call ${vaultAddress} "nativeTokenHash()" --rpc-url ${network.rpc_url}`);
      this.log(`   Native Token Hash: ${nativeTokenHash}`, colors.blue);
      if (nativeTokenHash !== this.tokens.eth.tokenHash) {
        this.log(`   ⚠️ Native Token Hash Not Allowed`, colors.yellow);
      } else {
        this.log(`   ✅ Native Token Hash Allowed`, colors.green);
      }

      const swapSigner = this.runCommand(`cast call ${vaultAddress} "swapSigner()" --rpc-url ${network.rpc_url}`);
      this.log(`   Swap Signer: ${swapSigner}`, colors.blue);

      const swapOperator = this.runCommand(`cast call ${vaultAddress} "swapOperator()" --rpc-url ${network.rpc_url}`);
      this.log(`   Swap Operator: ${swapOperator}`, colors.blue);

      // Check token allowance
      const usdtToken = this.tokens.usdt;
      const ethToken = this.tokens.eth;
      const usdcToken = this.tokens.usdc;

      const result = this.runCommand(`cast call ${vaultAddress} "getAllowedToken(bytes32)" ${usdtToken.tokenHash} --rpc-url ${network.rpc_url}`);
      // turn byte32 to address 0x000...001234567890123456789012345678901234567890, keep 0x123..
      const correctUsdtAddress = (network.usdt || this.usdtAddress || 'none-none-none').slice(2);
      const isMatchUsdtAddress = result.toLocaleLowerCase().includes(correctUsdtAddress.toLocaleLowerCase());
      this.log(`   USDT Token Allowed: ${result}`, colors.blue);
      this.log(`   Correct USDT Address: ${correctUsdtAddress}`, colors.blue);
      if (!isMatchUsdtAddress) {
        this.log(`   ⚠️ USDT Token Not Allowed`, colors.yellow);
      } else {
        this.log(`   ✅ USDT Token Allowed`, colors.green);
      }

      const enableTokens = this.runCommand(`cast call ${vaultAddress} "getAllRebalanceEnableToken()" --rpc-url ${network.rpc_url}`);
      this.log(`   Enable Tokens: ${enableTokens}`, colors.blue);

    } catch (error) {
      this.log(`   ⚠️ Some vault config checks failed: ${error}`, colors.yellow);
    }

    this.log('\n📊 Ledger Contract Configuration:', colors.cyan);

    try {
      // Check ledger configuration
      const isTokenAllowed = this.runCommand(`cast call ${vaultManager} "getAllowedToken(bytes32)" ${this.tokens.usdt.tokenHash} --rpc-url ${ledgerNetwork.rpc_url}`);
      this.log(`   USDT Token Allowed in VaultManager: ${isTokenAllowed === '0x0000000000000000000000000000000000000000000000000000000000000001' ? 'true' : 'false'}`, colors.blue);
      if (isTokenAllowed !== '0x0000000000000000000000000000000000000000000000000000000000000001') {
        this.log(`   ⚠️ USDT Token Not Allowed in VaultManager`, colors.yellow);
      } else {
        this.log(`   ✅ USDT Token Allowed in VaultManager`, colors.green);
      }

      const isEthAllowed = this.runCommand(`cast call ${vaultManager} "getAllowedToken(bytes32)" ${this.tokens.eth.tokenHash} --rpc-url ${ledgerNetwork.rpc_url}`);
      this.log(`   ETH Token Allowed in VaultManager: ${isEthAllowed === '0x0000000000000000000000000000000000000000000000000000000000000001' ? 'true' : 'false'}`, colors.blue);
      if (isEthAllowed !== '0x0000000000000000000000000000000000000000000000000000000000000001') {
        this.log(`   ⚠️ ETH Token Not Allowed in VaultManager`, colors.yellow);
      } else {
        this.log(`   ✅ ETH Token Allowed in VaultManager`, colors.green);
      }

      const vaultChainId = this.networks[this.vaultChain].chain_id;
      const ledgerChainId = this.networks[this.ledgerChain].chain_id;
      const isChainTokenAllowed = this.runCommand(`cast call ${vaultManager} "getAllowedChainToken(bytes32,uint256)" ${this.tokens.usdt.tokenHash} ${vaultChainId} --rpc-url ${ledgerNetwork.rpc_url}`);
      this.log(`   USDT Chain Token Allowed (${this.vaultChain}): ${isChainTokenAllowed === '0x0000000000000000000000000000000000000000000000000000000000000001' ? 'true' : 'false'}`, colors.blue);
      // if not allowed warning
      if (isChainTokenAllowed !== '0x0000000000000000000000000000000000000000000000000000000000000001') {
        this.log(`   ⚠️ USDT Chain Token Not Allowed (${this.vaultChain})`, colors.yellow);
      } else {
        this.log(`   ✅ USDT Chain Token Allowed (${this.vaultChain})`, colors.green);
      }

      const isEthChainTokenAllowed = this.runCommand(`cast call ${vaultManager} "getAllowedChainToken(bytes32,uint256)" ${this.tokens.eth.tokenHash} ${vaultChainId} --rpc-url ${ledgerNetwork.rpc_url}`);
      this.log(`   ETH Chain Token Allowed (${this.vaultChain}): ${isEthChainTokenAllowed === '0x0000000000000000000000000000000000000000000000000000000000000001' ? 'true' : 'false'}`, colors.blue);
      if (isEthChainTokenAllowed !== '0x0000000000000000000000000000000000000000000000000000000000000001') {
        this.log(`   ⚠️ ETH Chain Token Not Allowed (${this.vaultChain})`, colors.yellow);
      } else {
        this.log(`   ✅ ETH Chain Token Allowed (${this.vaultChain})`, colors.green);
      }

      // check eth token decimal
      const correctEthTokenDecimalOnVault = this.tokens.eth.exceptions?.[this.vaultChain]?.decimal || this.tokens.eth.decimal;
      const correctEthTokenDecimalOnLedger = this.tokens.eth.exceptions?.[this.ledgerChain]?.decimal || this.tokens.eth.decimal;
      const ethTokenDecimal = this.runCommand(`cast call ${ledgerChainInfo.ledgerCCManager} "tokenDecimalMapping(bytes32,uint256)" ${this.tokens.eth.tokenHash} ${vaultChainId} --rpc-url ${ledgerNetwork.rpc_url}`);
      this.log(`   ETH Token Decimal (${this.vaultChain}): ${ethTokenDecimal}`, colors.blue);
      // decimal is hex, convert to decimal
      const ethTokenDecimalDecimal = parseInt(ethTokenDecimal, 16);
      if (ethTokenDecimalDecimal !== correctEthTokenDecimalOnVault) {
        this.log(`   ⚠️ ETH Token Decimal Not Correct(${this.vaultChain})`, colors.yellow);
      } else {
        this.log(`   ✅ ETH Token Decimal Correct (${this.vaultChain})`, colors.green);
      }


      const ethTokenDecimalOnLedger = this.runCommand(`cast call ${ledgerChainInfo.ledgerCCManager} "tokenDecimalMapping(bytes32,uint256)" ${this.tokens.eth.tokenHash} ${ledgerChainId} --rpc-url ${ledgerNetwork.rpc_url}`);
      this.log(`   ETH Token Decimal on Ledger (${this.ledgerChain}): ${ethTokenDecimalOnLedger}`, colors.blue);
      const ethTokenDecimalOnLedgerDecimal = parseInt(ethTokenDecimalOnLedger, 16);
      if (ethTokenDecimalOnLedgerDecimal !== correctEthTokenDecimalOnLedger) {
        this.log(`   ⚠️ ETH Token Decimal Not Correct (${this.ledgerChain})`, colors.yellow);
      } else {
        this.log(`   ✅ ETH Token Decimal Correct (${this.ledgerChain})`, colors.green);
      }

      const correctUsdtTokenDecimalOnVault = this.tokens.usdt.exceptions?.[this.vaultChain]?.decimal || this.tokens.usdt.decimal;
      const correctUsdtTokenDecimalOnLedger = this.tokens.usdt.exceptions?.[this.ledgerChain]?.decimal || this.tokens.usdt.decimal;

      const usdtTokenDecimal = this.runCommand(`cast call ${ledgerChainInfo.ledgerCCManager} "tokenDecimalMapping(bytes32,uint256)" ${this.tokens.usdt.tokenHash} ${vaultChainId} --rpc-url ${ledgerNetwork.rpc_url}`);
      this.log(`   USDT Token Decimal (${this.vaultChain}): ${usdtTokenDecimal}`, colors.blue);
      const usdtTokenDecimalDecimal = parseInt(usdtTokenDecimal, 16);
      if (usdtTokenDecimalDecimal !== correctUsdtTokenDecimalOnVault) {
        this.log(`   ⚠️ USDT Token Decimal Not Correct (${this.vaultChain})`, colors.yellow);
      } else {
        this.log(`   ✅ USDT Token Decimal Correct (${this.vaultChain})`, colors.green);
      }

      const usdtTokenDecimalOnLedger = this.runCommand(`cast call ${ledgerChainInfo.ledgerCCManager} "tokenDecimalMapping(bytes32,uint256)" ${this.tokens.usdt.tokenHash} ${ledgerChainId} --rpc-url ${ledgerNetwork.rpc_url}`);
      this.log(`   USDT Token Decimal on Ledger (${this.ledgerChain}): ${usdtTokenDecimalOnLedger}`, colors.blue);
      const usdtTokenDecimalOnLedgerDecimal = parseInt(usdtTokenDecimalOnLedger, 16);
      if (usdtTokenDecimalOnLedgerDecimal !== correctUsdtTokenDecimalOnLedger) {
        this.log(`   ⚠️ USDT Token Decimal Not Correct (${this.ledgerChain})`, colors.yellow);
      } else {
        this.log(`   ✅ USDT Token Decimal Correct (${this.ledgerChain})`, colors.green);
      }

    } catch (error) {
      this.log(`   ⚠️ Some ledger config checks failed: ${error}`, colors.yellow);
    }

    this.log('\n✅ Configuration check completed!', colors.green);
  }

  async run(isFirstTime: boolean = false, deployUsdt: boolean = false, upgradeVaultOnly: boolean = false, upgradeLedgerOnly: boolean = false, upgradeLedgerConfig: LedgerUpgradeConfig, setupVaultOnly: boolean = false, setupLedgerOnly: boolean = false, executeProposal: boolean = false, proposalPath: string = '') {
    this.log('🚀 Starting Vault Chain Deployment and Setup', colors.magenta);
    this.log(`   Vault Chain: ${this.vaultChain}`, colors.blue);
    this.log(`   Ledger Chain: ${this.ledgerChain}`, colors.blue);
    this.log(`   Safe Tasks Path: ${this.safeTasksPath}`, colors.blue);
    this.log(`   Environment: ${this.environment}`, colors.blue);
    this.log(`   First Time Setup: ${isFirstTime ? 'Yes' : 'No'}`, colors.blue);

    if (executeProposal) {
      this.log(`   Execute Proposal`, colors.blue);
      if (proposalPath) {
        // e.g. safeTasksPath: ../safe-tasks
        // e.g. proposalPath: ../safe-tasks/proposal/vault/upgrade.json
        // relative proposal path: proposal/vault/upgrade.json
        const relativeProposalPath = proposalPath.replace(this.safeTasksPath, '').replace(/^\//, '');
        console.log(`   Relative Proposal Path: ${relativeProposalPath}`);
        const cmd = `yarn safe propose-multi --network ${this.vaultChain.toLocaleLowerCase()} --env ${this.environment} ${relativeProposalPath}`;
        this.log(`   Execute Proposal Command: ${cmd}`, colors.blue);
        const output = this.runCommand(cmd, 3, this.safeTasksPath);
        this.log(`   Execute Proposal Output: ${output}`, colors.blue);
        const safeHashMatch = output.match(/Safe transaction hash: (0x[a-fA-F0-9]{64})/);
        const safeTransactionHash = safeHashMatch?.[1];
        if (safeTransactionHash) {
          // run execute proposal
          await this.signAndSubmitProposal(this.vaultChain, safeTransactionHash, 'submiting proposal');
        } else {
          this.exitWithError('Failed to get proposal hash');
        }
      } else {
        this.exitWithError('Please provide a proposal path');
      }
      return;
    }
  
    if (setupVaultOnly) {
      this.log(`   Setup Vault Only`, colors.blue);
      // run setup vault
      const vaultSetupSafeHash = await this.setupVault();
      if (this.environment === 'dev' || this.environment === 'qa') {
        await this.signAndSubmitProposal(this.vaultChain, vaultSetupSafeHash, 'vault setup proposal');
      } else {
        this.log(`✅ Vault setup proposal created: ${vaultSetupSafeHash}, environment: ${this.environment}`, colors.green);
        this.log(`✅ Please check the proposal and sign&submit it manually`, colors.green);
      }
      return;
    }
    if (setupLedgerOnly) {
      this.log(`   Setup Ledger Only`, colors.blue);
      // run setup ledger
      const ledgerSetupSafeHash = await this.setupLedger(isFirstTime);
      if (this.environment === 'dev' || this.environment === 'qa') {
        await this.signAndSubmitProposal(this.ledgerChain, ledgerSetupSafeHash, 'ledger setup proposal');
      } else {
        this.log(`✅ Ledger setup proposal created: ${ledgerSetupSafeHash}, environment: ${this.environment}`, colors.green);
        this.log(`✅ Please check the proposal and sign&submit it manually`, colors.green);
      }
      return;
    }


    try {
      if (!upgradeVaultOnly) {
        // Prerequisites
        const upgradeLedgerSafeTransactionHash = await this.upgradeLedgerContract(upgradeLedgerConfig);
        if (upgradeLedgerSafeTransactionHash) {
          if (this.environment === 'dev' || this.environment === 'qa') {
            await this.signAndSubmitProposal(this.ledgerChain, upgradeLedgerSafeTransactionHash, 'Upgrade ledger side contracts');
          } else {
            this.log(`✅ Upgrade proposal created: ${upgradeLedgerSafeTransactionHash}, environment: ${this.environment}`, colors.green);
            this.log(`✅ Please check the proposal and sign&submit it manually`, colors.green);
          }
        }
        if (upgradeLedgerOnly) {
          this.log('\n🎉 All steps completed successfully!', colors.green);
          this.log('✨ Ledger chain upgrade finished.', colors.green);
          return;
        }
      }

      // Deploy Vault Contract
      const contractAddress = await this.deployVaultContract(deployUsdt);

      // Upgrade Vault Contract
      const upgradeSafeHash = await this.upgradeVaultContract(contractAddress);
      if (this.environment === 'dev' || this.environment === 'qa') {
        await this.signAndSubmitProposal(this.vaultChain, upgradeSafeHash, 'vault upgrade proposal');
      } else {
        this.log(`✅ Upgrade proposal created: ${upgradeSafeHash}, environment: ${this.environment}`, colors.green);
        this.log(`✅ Please check the proposal and sign&submit it manually`, colors.green);
      }
      if (upgradeVaultOnly) {
        this.log('\n🎉 All steps completed successfully!', colors.green);
        this.log('✨ Vault chain upgrade finished.', colors.green);
        return;
      }

      // Setup Vault
      const vaultSetupSafeHash = await this.setupVault();
      if (this.environment === 'dev' || this.environment === 'qa') {
        await this.signAndSubmitProposal(this.vaultChain, vaultSetupSafeHash, 'vault setup proposal');
      } else {
        this.log(`✅ Vault setup proposal created: ${vaultSetupSafeHash}, environment: ${this.environment}`, colors.green);
        this.log(`✅ Please check the proposal and sign&submit it manually`, colors.green);
      }

      // Setup Ledger
      const ledgerSetupSafeHash = await this.setupLedger(isFirstTime);
      if (this.environment === 'dev' || this.environment === 'qa') {
        await this.signAndSubmitProposal(this.ledgerChain, ledgerSetupSafeHash, 'ledger setup proposal');
      } else {
        this.log(`✅ Ledger setup proposal created: ${ledgerSetupSafeHash}, environment: ${this.environment}`, colors.green);
        this.log(`✅ Please check the proposal and sign&submit it manually`, colors.green);
      }

      // Check Configuration
      if (this.environment === 'dev' || this.environment === 'qa') {
        await this.checkContractConfig();
      } else {
        this.log(`✅ Configuration check skipped, environment: ${this.environment}`, colors.green);
      }

      this.log('\n🎉 All steps completed successfully!', colors.green);
      this.log('✨ Vault chain deployment and setup finished.', colors.green);

    } catch (error) {
      this.exitWithError(`Deployment process failed: ${error}`);
    }
  }
}

interface ParsedArgs {
  vaultChain: string;
  ledgerChain: string;
  safeTasksPath: string;
  environment: string;
  isFirstTime: boolean;
  deployUsdt: boolean;
  upgradeVaultOnly: boolean;
  upgradeLedgerOnly: boolean;
  setupVaultOnly: boolean;
  setupLedgerOnly: boolean;
  executeProposal: boolean;
  proposalPath: string;
}

function setupYargs() {
  return yargs(hideBin(process.argv))
    .usage('$0 <vaultChain> <ledgerChain> <safeTasksPath> [options]')
    .command('* <vaultChain> <ledgerChain> <safeTasksPath>', 'Deploy and setup a new Vault contract', (yargs) => {
      return yargs
        .positional('vaultChain', {
          describe: 'The vault chain name (e.g., baseSepolia, arbitrumSepolia)',
          type: 'string',
          demandOption: true
        })
        .positional('ledgerChain', {
          describe: 'The ledger chain name (e.g., orderlySepolia)',
          type: 'string',
          demandOption: true
        })
        .positional('safeTasksPath', {
          describe: 'Path to the safe-tasks repository',
          type: 'string',
          demandOption: true
        });
    })
    .option('environment', {
      alias: 'e',
      type: 'string',
      default: 'dev',
      choices: ['dev', 'qa', 'staging', 'prod'],
      describe: 'Environment to use'
    })
    .option('upgrade-vault-only', {
      type: 'boolean',
      default: false,
      describe: 'Upgrade vault only'
    })
    .option('upgrade-ledger-only', {
      type: 'boolean',
      default: false,
      describe: 'Upgrade ledger only'
    })
    .option('first-time', {
      alias: 'f',
      type: 'boolean',
      default: false,
      describe: 'First time setup (includes token allowance setup)'
    })
    .option('deploy-usdt', {
      type: 'boolean',
      default: false,
      describe: 'Deploy USDT contract during vault deployment'
    })
    .option('ledger', {
      type: 'boolean',
      default: false,
      describe: 'Upgrade ledger contracts'
    })
    .option('ledgerA', {
      type: 'boolean',
      default: false,
      describe: 'Upgrade ledger impl A contract'
    })
    .option('ledgerB', {
      type: 'boolean',
      default: false,
      describe: 'Upgrade ledger impl B contract'
    })
    .option('ledgerC', {
      type: 'boolean',
      default: false,
      describe: 'Upgrade ledger impl C contract'
    })
    .option('ledgerD', {
      type: 'boolean',
      default: false,
      describe: 'Upgrade ledger impl D contract'
    })
    .option('operatorManager', {
      type: 'boolean',
      default: false,
      describe: 'Upgrade operator manager contract'
    })
    .option('operatorManagerA', {
      type: 'boolean',
      default: false,
      describe: 'Upgrade operator manager impl A contract'
    })
    .option('operatorManagerB', {
      type: 'boolean',
      default: false,
      describe: 'Upgrade operator manager impl B contract'
    })
    .option('vaultManager', {
      type: 'boolean',
      default: false,
      describe: 'Upgrade vault manager contract'
    })
    .option('feeManager', {
      type: 'boolean',
      default: false,
      describe: 'Upgrade fee manager contract'
    })
    .option('allLedgerContracts', {
      type: 'boolean',
      default: false,
      describe: 'Upgrade all ledger contracts'
    })
    .option('setup-vault-only', {
      type: 'boolean',
      default: false,
      describe: 'Setup vault only'
    })
    .option('setup-ledger-only', {
      type: 'boolean',
      default: false,
      describe: 'Setup ledger only'
    })
    .option('execute-proposal', {
      type: 'boolean',
      default: false,
      describe: 'Execute proposal'
    })
    .option('proposal-path', {
      type: 'string',
      default: '',
      describe: 'Path to the proposal file'
    })
    .example('$0 baseSepolia orderlySepolia /path/to/safe-tasks', 'Basic usage')
    .example('$0 baseSepolia orderlySepolia /path/to/safe-tasks --first-time --deploy-usdt', 'First time setup with USDT deployment')
    .example('$0 baseSepolia orderlySepolia /path/to/safe-tasks -e qa -f -d', 'Using short flags')
    .help()
    .alias('help', 'h')
    .check((argv) => {
      // Validate safe tasks path exists
      if (!fs.existsSync(argv.safeTasksPath as string)) {
        throw new Error(`Safe tasks path does not exist: ${argv.safeTasksPath}`);
      }
      return true;
    })
    .wrap(yargs().terminalWidth());

}

// Main execution
async function main() {
  try {
    const argv = await setupYargs().parseAsync();
    
    const args: ParsedArgs = {
      vaultChain: argv.vaultChain as string,
      ledgerChain: argv.ledgerChain as string,
      safeTasksPath: argv.safeTasksPath as string,
      environment: argv.environment as string,
      isFirstTime: argv.firstTime as boolean,
      deployUsdt: argv.deployUsdt as boolean,
      upgradeVaultOnly: argv.upgradeVaultOnly as boolean,
      upgradeLedgerOnly: argv.upgradeLedgerOnly as boolean,
      setupVaultOnly: argv.setupVaultOnly as boolean,
      setupLedgerOnly: argv.setupLedgerOnly as boolean,
      executeProposal: argv.executeProposal as boolean,
      proposalPath: argv.proposalPath as string
    };

    const ledgerUpgradeConfig: LedgerUpgradeConfig = {
        ledger: argv.ledger as boolean,
        ledgerImplA: argv.ledgerA as boolean,
        ledgerImplB: argv.ledgerB as boolean,
        ledgerImplC: argv.ledgerC as boolean,
        ledgerImplD: argv.ledgerD as boolean,
        operatorManager: argv.operatorManager as boolean,
        operatorManagerImplA: argv.operatorManagerA as boolean,
        operatorManagerImplB: argv.operatorManagerB as boolean,
        vaultManager: argv.vaultManager as boolean,
        feeManager: argv.feeManager as boolean
    };
    const deployAllLedgerContracts = argv.allLedgerContracts as boolean;
    if (deployAllLedgerContracts) {
        ledgerUpgradeConfig.ledger = true;
        ledgerUpgradeConfig.ledgerImplA = true;
        ledgerUpgradeConfig.ledgerImplB = true;
        ledgerUpgradeConfig.ledgerImplC = true;
        ledgerUpgradeConfig.ledgerImplD = true;
        ledgerUpgradeConfig.operatorManager = true;
        ledgerUpgradeConfig.operatorManagerImplA = true;
        ledgerUpgradeConfig.operatorManagerImplB = true;
        ledgerUpgradeConfig.vaultManager = true;
        ledgerUpgradeConfig.feeManager = true;
    }

    if (args.environment === 'dev') {
      ledgerUpgradeConfig.vaultManager = false;
      console.log(`${colors.yellow} Please upgrade Vault Manager manually ${colors.reset}`);
    }

    console.log(`${colors.cyan}🚀 Starting Vault Chain Deployment and Setup${colors.reset}`);
    console.log(`${colors.blue}   Vault Chain: ${args.vaultChain}${colors.reset}`);
    console.log(`${colors.blue}   Ledger Chain: ${args.ledgerChain}${colors.reset}`);
    console.log(`${colors.blue}   Safe Tasks Path: ${args.safeTasksPath}${colors.reset}`);
    console.log(`${colors.blue}   Environment: ${args.environment}${colors.reset}`);
    console.log(`${colors.blue}   First Time Setup: ${args.isFirstTime ? 'Yes' : 'No'}${colors.reset}`);
    console.log(`${colors.blue}   Deploy USDT: ${args.deployUsdt ? 'Yes' : 'No'}${colors.reset}\n`);
    console.log(`${colors.blue}   Upgrade All Ledger Contracts: ${deployAllLedgerContracts ? 'Yes' : 'No'}${colors.reset}`);
    console.log(`${colors.blue}   Upgrade Config: ${JSON.stringify(ledgerUpgradeConfig, null, 2)}${colors.reset}`);

    const deployer = new VaultChainDeployer(args.vaultChain, args.ledgerChain, args.safeTasksPath, args.environment);
    await deployer.run(args.isFirstTime, args.deployUsdt, args.upgradeVaultOnly, args.upgradeLedgerOnly, ledgerUpgradeConfig, args.setupVaultOnly, args.setupLedgerOnly, args.executeProposal, args.proposalPath);
    
  } catch (error) {
    console.error(`${colors.red}Error: ${error}${colors.reset}`);
    process.exit(1);
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error(`${colors.red}Unhandled error: ${error}${colors.reset}`);
    process.exit(1);
  });
}

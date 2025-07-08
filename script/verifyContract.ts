#!/usr/bin/env ts-node

/**
 * Contract Verification Script
 * 
 * Verifies contracts on blockchain explorers (Etherscan/Blockscout) using forge verify-contract.
 * 
 * Usage as script:
 *   ./script/verifyContract.ts <address> <chain> [options]
 *   
 * Usage as module:
 *   import { verifyContract, encodeConstructorArgs } from './script/verifyContract';
 *   
 * Constructor Arguments:
 *   For contracts with constructor arguments, provide both signature and args:
 *   --signature "constructor(string,string,uint8)" --constructor-args "tUSDT" "TUSDT" "8"
 *   
 * Examples:
 *   ./script/verifyContract.ts 0x1234...5678 baseSepolia
 *   ./script/verifyContract.ts 0x1234...5678 mainnet --signature "constructor(string,uint8)" --constructor-args "Token" "18"
 */

import * as fs from 'fs';
import * as path from 'path';
import yargs from 'yargs';
import { hideBin } from 'yargs/helpers';
import { runCommand } from './runCommand';

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
}

interface VerifyContractOptions {
  retryTimes?: number;
  constructorArgs?: string[];  // Individual constructor arguments
  signature?: string;  // Constructor signature for encoding
  contractPath?: string;
  silent?: boolean;
}

/**
 * Log a message with optional color
 */
function log(message: string, color: string = colors.reset) {
  console.log(`${color}${message}${colors.reset}`);
}

/**
 * Load network configurations from the contract helper
 */
function loadNetworkConfigurations(): Record<string, NetworkConfig> {
  try {
    const contractHelperPath = path.resolve('../contract_helper/contract_info');
    const networksPath = path.join(contractHelperPath, 'networks.json');
    
    if (!fs.existsSync(networksPath)) {
      throw new Error(`Networks configuration file not found: ${networksPath}`);
    }
    
    const networks = JSON.parse(fs.readFileSync(networksPath, 'utf8'));
    return networks;
  } catch (error) {
    throw new Error(`Failed to load network configurations: ${error}`);
  }
}

/**
 * Encode constructor arguments using cast abi-encode
 * 
 * @param signature - Constructor signature (e.g., "constructor(string,string,uint8)")
 * @param args - Constructor arguments
 * @returns Encoded constructor arguments string
 */
export function encodeConstructorArgs(signature: string, args: string[]): string {
  const command = `cast abi-encode "${signature}" ${args.map(arg => `"${arg}"`).join(' ')}`;
  
  try {
    const result = runCommand(command, {
      retryNum: 1,
      exitOnError: false,
      silent: true
    });
    return result;
  } catch (error) {
    throw new Error(`Failed to encode constructor arguments: ${error}`);
  }
}

/**
 * Build the forge verify command based on network configuration
 */
function buildVerifyCommand(
  contractAddress: string,
  network: NetworkConfig,
  chainName: string,
  options: VerifyContractOptions = {}
): string {
  const { constructorArgs, signature, contractPath } = options;
  
  const isEtherscan = network.explorer_type === 'etherscan';
  const verifier = isEtherscan ? 'etherscan' : 'blockscout';
  
  let command = `source .env && forge verify-contract ${contractAddress}`;
  
  // Add contract path if provided
  if (contractPath) {
    command += ` ${contractPath}`;
  }
  
  // Add RPC URL
  command += ` -r ${network.rpc_url}`;
  
  // Add verifier and verifier URL
  command += ` --verifier ${verifier}`;
  if (network.explorer_api_url) {
    command += ` --verifier-url ${network.explorer_api_url}`;
  }
  
  // Add etherscan API key if it's etherscan
  if (isEtherscan) {
    command += ` --etherscan-api-key $${chainName.toUpperCase()}_ETHERSCAN_API_KEY`;
  }
  
  // Add chain ID
  command += ` --chain-id ${network.chain_id}`;
  
  // Add constructor arguments if provided
  if (constructorArgs && constructorArgs.length > 0) {
    if (signature) {
      // Encode the constructor arguments using the signature
      try {
        const encodedArgs = encodeConstructorArgs(signature, constructorArgs);
        command += ` --constructor-args ${encodedArgs}`;
      } catch (error) {
        throw new Error(`Failed to encode constructor arguments: ${error}`);
      }
    } else {
      throw new Error('Constructor signature is required when constructor arguments are provided');
    }
  }
  
  return command;
}

/**
 * Verify a contract on the blockchain explorer
 * 
 * @param contractAddress - The deployed contract address
 * @param chainName - The chain name (e.g., 'baseSepolia', 'arbitrumSepolia')
 * @param options - Additional verification options
 * @param options.constructorArgs - Individual constructor arguments as string array
 * @param options.signature - Constructor signature for encoding (e.g., 'constructor(string,string,uint8)')
 * @param options.retryTimes - Number of retry attempts (default: 3)
 * @param options.contractPath - Contract path specification (e.g., 'src/Contract.sol:Contract')
 * @param options.silent - Suppress logging output (default: false)
 * @returns True if verification succeeded, false otherwise
 */
export async function verifyContract(
  contractAddress: string,
  chainName: string,
  options: VerifyContractOptions = {}
): Promise<boolean> {
  const { retryTimes = 3, silent = false } = options;
  
  try {
    if (!silent) {
      log(`🔍 Starting contract verification`, colors.magenta);
      log(`   Contract: ${contractAddress}`, colors.blue);
      log(`   Chain: ${chainName}`, colors.blue);
      log(`   Retry attempts: ${retryTimes}`, colors.blue);
      if (options.signature) {
        log(`   Constructor signature: ${options.signature}`, colors.blue);
      }
      if (options.constructorArgs && options.constructorArgs.length > 0) {
        log(`   Constructor args: [${options.constructorArgs.join(', ')}]`, colors.blue);
      }
    }
    
    // Validate contract address format
    if (!/^0x[a-fA-F0-9]{40}$/.test(contractAddress)) {
      throw new Error(`Invalid contract address format: ${contractAddress}`);
    }
    
    // Load network configurations
    const networks = loadNetworkConfigurations();
    const network = networks[chainName];
    
    if (!network) {
      throw new Error(`Network '${chainName}' not found in configuration. Available networks: ${Object.keys(networks).join(', ')}`);
    }
    
    if (!silent) {
      log(`   Network: ${network.name} (Chain ID: ${network.chain_id})`, colors.blue);
      log(`   Explorer: ${network.explorer}`, colors.blue);
      log(`   Verifier: ${network.explorer_type === 'etherscan' ? 'Etherscan' : 'Blockscout'}`, colors.blue);
    }
    
    // Build verification command
    const verifyCommand = buildVerifyCommand(contractAddress, network, chainName, options);
    
    if (!silent) {
      log(`\n🔄 Executing verification command...`, colors.cyan);
    }
    
    // Execute verification with retry
    const result = runCommand(verifyCommand, {
      retryNum: retryTimes,
      exitOnError: false,
      silent
    });
    
    if (result) {
      if (!silent) {
        log(`✅ Contract verification completed successfully!`, colors.green);
        log(`   Explorer URL: ${network.explorer}/address/${contractAddress}`, colors.blue);
      }
      return true;
    } else {
      if (!silent) {
        log(`⚠️  Contract verification failed after ${retryTimes} attempts`, colors.yellow);
        log(`   Note: Contract may already be verified, or there may be temporary issues`, colors.yellow);
        log(`   You can check manually at: ${network.explorer}/address/${contractAddress}`, colors.blue);
      }
      return false;
    }
    
  } catch (error) {
    if (!silent) {
      log(`⚠️  Contract verification error: ${error}`, colors.yellow);
      log(`   This is not critical - contract deployment was successful`, colors.yellow);
    }
    return false;
  }
}

/**
 * Setup command line arguments when running as a script
 */
function setupYargs() {
  return yargs(hideBin(process.argv))
    .usage('$0 <address> <chain> [options]')
    .command('* <address> <chain>', 'Verify a contract on blockchain explorer', (yargs) => {
      return yargs
        .positional('address', {
          describe: 'The deployed contract address',
          type: 'string',
          demandOption: true
        })
        .positional('chain', {
          describe: 'The chain name (e.g., baseSepolia, arbitrumSepolia)',
          type: 'string',
          demandOption: true
        });
    })
    .option('retry', {
      alias: 'r',
      type: 'number',
      default: 3,
      describe: 'Number of retry attempts'
    })
    .option('constructor-args', {
      alias: 'c',
      type: 'array',
      describe: 'Constructor arguments (individual values)'
    })
    .option('signature', {
      alias: 'sig',
      type: 'string',
      describe: 'Constructor signature (e.g., "constructor(string,string,uint8)")'
    })
    .option('contract-path', {
      alias: 'p',
      type: 'string',
      describe: 'Contract path (e.g., src/Contract.sol:Contract)'
    })
    .option('silent', {
      alias: 's',
      type: 'boolean',
      default: false,
      describe: 'Suppress output logging'
    })
    .example('$0 0x1234...5678 baseSepolia', 'Verify contract on Base Sepolia')
    .example('$0 0x1234...5678 arbitrumSepolia --retry 5', 'Verify with 5 retry attempts')
    .example('$0 0x1234...5678 mainnet --signature "constructor(string,string,uint8)" --constructor-args "tUSDT" "TUSDT" "8"', 'Verify with constructor arguments')
    .example('$0 0x1234...5678 polygon --contract-path "src/MyContract.sol:MyContract"', 'Verify with specific contract path')
    .help()
    .alias('help', 'h')
    .wrap(yargs().terminalWidth());
}

// Main execution when running as a script
async function main() {
  try {
    const argv = await setupYargs().parseAsync();
    
    const address = argv.address as string;
    const chain = argv.chain as string;
    const options: VerifyContractOptions = {
      retryTimes: argv.retry as number,
      constructorArgs: argv.constructorArgs as string[],
      signature: argv.signature as string,
      contractPath: argv.contractPath as string,
      silent: argv.silent as boolean
    };

    if (!options.silent) {
      log('🚀 Starting contract verification process', colors.magenta);
    }
    
    const success = await verifyContract(address, chain, options);
    
    if (success) {
      if (!options.silent) {
        log('\n🎉 Contract verification completed successfully!', colors.green);
      }
      process.exit(0);
    } else {
      if (!options.silent) {
        log('\n⚠️  Contract verification failed, but this is not critical', colors.yellow);
      }
      process.exit(0); // Don't exit with error for verification failures
    }
    
  } catch (error) {
    log(`Error: ${error}`, colors.red);
    process.exit(1);
  }
}

// Export for use as module and run as script if executed directly
if (require.main === module) {
  main().catch((error) => {
    log(`Unhandled error: ${error}`, colors.red);
    process.exit(1);
  });
}

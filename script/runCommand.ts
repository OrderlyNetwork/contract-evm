#!/usr/bin/env ts-node

import { execSync } from 'child_process';
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

interface RunCommandOptions {
  retryNum?: number;
  cwd?: string;
  exitOnError?: boolean;
  silent?: boolean;
}

/**
 * Log a message with optional color
 */
function log(message: string, color: string = colors.reset) {
  console.log(`${color}${message}${colors.reset}`);
}

/**
 * Exit with error message and optional command
 */
function exitWithError(message: string, command?: string) {
  log(`❌ Error: ${message}`, colors.red);
  if (command) {
    log(`❌ Failed command: ${command}`, colors.red);
  }
  process.exit(1);
}

/**
 * Run a command with retry support and comprehensive logging
 * 
 * @param command - The command to execute
 * @param options - Configuration options
 * @returns The command output as a string, or empty string if failed and exitOnError is false
 */
export function runCommand(command: string, options: RunCommandOptions = {}): string {
  const {
    retryNum = 1,
    cwd = process.cwd(),
    exitOnError = true,
    silent = false
  } = options;

  let attempts = retryNum;
  let lastError: any;

  while (attempts > 0) {
    try {
      if (!silent) {
        log(`🔄 Running (attempt ${retryNum - attempts + 1}/${retryNum}): ${command}`, colors.cyan);
        if (cwd !== process.cwd()) {
          log(`📁 Working directory: ${cwd}`, colors.blue);
        }
      }

      const result = execSync(command, { 
        encoding: 'utf8', 
        cwd,
        stdio: 'pipe'
      });

      if (!silent) {
        log(`✅ Command completed successfully`, colors.green);
        log(`${result}`, colors.green);
      }
      
      return result.trim();
    } catch (error: any) {
      lastError = error;
      attempts--;
      
      if (!silent) {
        log(`⚠️  Command failed (${retryNum - attempts}/${retryNum}): ${error.message}`, colors.yellow);
        if (error.stderr) {
          log(`stderr: ${error.stderr}`, colors.red);
        }
        if (error.stdout) {
          log(`stdout: ${error.stdout}`, colors.yellow);
        }
      }
      
      if (attempts > 0 && !silent) {
        log(`🔄 Retrying in 1 second...`, colors.yellow);
        // Simple sleep for 1 second
        execSync('sleep 1');
      }
    }
  }

  // All attempts failed
  if (!silent) {
    log(`❌ Command failed after ${retryNum} attempts`, colors.red);
  }

  if (exitOnError) {
    exitWithError(`Command failed after ${retryNum} attempts: ${lastError?.message}`, command);
  }
  
  return '';
}

/**
 * Setup command line arguments when running as a script
 */
function setupYargs() {
  return yargs(hideBin(process.argv))
    .usage('$0 <command> [options]')
    .command('* <command>', 'Run a command with retry support', (yargs) => {
      return yargs
        .positional('command', {
          describe: 'The command to execute',
          type: 'string',
          demandOption: true
        });
    })
    .option('retry', {
      alias: 'r',
      type: 'number',
      default: 1,
      describe: 'Number of retry attempts'
    })
    .option('cwd', {
      alias: 'd',
      type: 'string',
      describe: 'Working directory for the command'
    })
    .option('exit-on-error', {
      alias: 'e',
      type: 'boolean',
      default: true,
      describe: 'Exit process on command failure'
    })
    .option('silent', {
      alias: 's',
      type: 'boolean',
      default: false,
      describe: 'Suppress output logging'
    })
    .example('$0 "npm test"', 'Run npm test once')
    .example('$0 "npm test" --retry 3', 'Run npm test with 3 retry attempts')
    .example('$0 "ls -la" --cwd /tmp', 'Run ls in /tmp directory')
    .example('$0 "flaky-command" --retry 5 --no-exit-on-error', 'Run command with retries, don\'t exit on failure')
    .help()
    .alias('help', 'h')
    .wrap(yargs().terminalWidth());
}

// Main execution when running as a script
async function main() {
  try {
    const argv = await setupYargs().parseAsync();
    
    const command = argv.command as string;
    const options: RunCommandOptions = {
      retryNum: argv.retry as number,
      cwd: argv.cwd as string,
      exitOnError: argv.exitOnError as boolean,
      silent: argv.silent as boolean
    };

    log('🚀 Starting command execution', colors.magenta);
    
    const result = runCommand(command, options);
    
    if (result && !options.silent) {
      log('\n📋 Command output:', colors.blue);
      console.log(result);
    }
    
    if (!options.silent) {
      log('\n🎉 Command execution completed successfully!', colors.green);
    }
    
  } catch (error) {
    log(`Unhandled error: ${error}`, colors.red);
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

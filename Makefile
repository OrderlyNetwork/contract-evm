.PHONY: all
all: help

# include .envrc file and export its env vars
# (-include to ignore error if it does not exist)
-include .envrc

.PHONY: build # Build the project
build:
	forge clean && forge build

.PHONY: lint # Lint code
lint:
	solhint './src/**/*.sol'

.PHONY: test # Run tests
test:
	forge test -vvv

.PHONY: update # Update Dependencies
update:
	forge update

.PHONY: deploy # Deploy contract
deploy:
	forge create --rpc-url "https://api.avax-test.network/ext/bc/C/rpc" --private-key ${PRIVATE_KEY} ./src/AssetManager.sol:AssetManager --verify --etherscan-api-key ${ETHERSCAN_KEY} --verifier etherscan

.PHONY: clean # Clean build files
clean:
	forge clean

.PHONY: help # Generate list of targets with descriptions
help:
	@grep '^.PHONY: .* #' Makefile | sed 's/\.PHONY: \(.*\) # \(.*\)/\1	\2/' | expand -t20
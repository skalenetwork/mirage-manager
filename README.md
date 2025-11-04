# FAIR Manager

A smart contract system that orchestrates and operates the FAIR chain. For more details of each smart contract, check [SPEC.md](./SPEC.md)

## Install & Compile

1. Clone the repository with all submodules
2. Run `yarn install && yarn compile`

## Deployment

FAIR Manager is started from a [fair-boot](https://github.com/skalenetwork/skale-manager) instance. We recommend using the default parameters if you are simply testing deployment of FAIR Manager.

Create a `.env` file in the project root directory with the following data:

```bash
MAINNET_ENDPOINT="https://your.endpoint.to.eth.mainnet.com"
TARGET="production"
CHAIN_NAME="affectionate-immediate-pollux"
```

If you are testing locally, this is enough and you can run: `yarn hardhat run migrations/deploy.ts`

Instead of the previous steps, you can simply run `bash scripts/test_deploy.sh`. You can change the MAINNET_ENDPOINT value to whichever you prefer inside the script.

If you want to deploy to another network other than the Hardhat local network, set the extra variables in the `.env` file:

```bash
PRIVATE_KEY="{your private key}"
ENDPOINT="https://endpoint.to.destination.network.com"
```

Then run `yarn hardhat run migrations/deploy.ts --network custom`

## Test

You can run unit & integration tests locally without any extra setup. Simply run: `yarn test`

To run fuzz tests, make sure you install foundry locally, and then run:

- For Red-Black Tree Fuzz Tests: `yarn test-foundry:rbt`;
- For Fair Manager Fuzz Tests: `yarn test-foundry:fair-manager`;

To increase or decrease tested cases in fuzz tests, change [foundry.toml](./foundry.toml) file and increase depth or number of runs (Increasing depth over 150 should be less relevant than increasing runs).

To clean cache generated from past runs, use `forge clean`. Foundry caches information gained during past test runs.

## Verification

Contract verification allows you to verify deployed smart contracts on block explorers using Hardhat's verification plugin via command line interface.

### Required Environment Variables

```bash
ENDPOINT="https://endpoint.to.destination.network"
CHAIN_ID="your_chain_id"
EXPLORER_URL="https://your.explorer.url.com"
```

### Usage

```bash
yarn hardhat verify --network custom <ContractAddress>
```

## License

[![License](https://img.shields.io/github/license/skalenetwork/fair-manager.svg)](LICENSE)

Copyright (C) 2025-present SKALE Labs

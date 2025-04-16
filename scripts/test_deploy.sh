#!/usr/bin/env bash

set -e
export TARGET=$TARGET
export MAINNET_ENDPOINT=$MAINNET_ENDPOINT
export CHAIN_HASH=$CHAIN_HASH
yarn hardhat run migrations/deploy.ts

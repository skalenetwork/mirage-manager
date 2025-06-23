#!/usr/bin/env bash
// Cspell:words hoodi

set -e
export MAINNET_ENDPOINT="http://hoodi-qa-geth.skalenodes.com:8545"
export CHAIN_NAME="mirage-qa-hoodi-1"
export TARGET="0x5ef7849BF607Cbdb1f48cA82E38Fb567c7A77316"

yarn hardhat run migrations/deploy.ts

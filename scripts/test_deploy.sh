#!/usr/bin/env bash
// Cspell:words hoodi

set -e
if [ -n "$INFURA_API_TOKEN" ]; then
    export MAINNET_ENDPOINT="https://mainnet.infura.io/v3/${INFURA_API_TOKEN}"
else
    export MAINNET_ENDPOINT="https://eth.llamarpc.com"
fi
export CHAIN_NAME="affectionate-immediate-pollux"
export TARGET="production"

yarn hardhat run migrations/deploy.ts

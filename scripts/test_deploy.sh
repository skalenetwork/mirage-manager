#!/usr/bin/env bash

set -e
if [ -n "$INFURA_API_TOKEN" ]; then
    export MAINNET_ENDPOINT="https://mainnet.infura.io/v3/${INFURA_API_TOKEN}"
else
    export MAINNET_ENDPOINT="https://eth.llamarpc.com"
fi
export CHAIN_HASH="0x000003d28774d2845ee8b9f656cc77328199a7a69b03ce2b9578f230be679c9f"
export TARGET="production"

yarn hardhat run migrations/deploy.ts

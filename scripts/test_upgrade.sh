#!/usr/bin/env bash

# cspell:words realpath show-toplevel

set -e

if [ -z $GITHUB_WORKSPACE ]
then
    GITHUB_WORKSPACE="$(git rev-parse --show-toplevel)"
fi

if [ -z $GITHUB_REPOSITORY ]
then
    GITHUB_REPOSITORY="skalenetwork/fair-manager"
fi

export NVM_DIR=~/.nvm;
source $NVM_DIR/nvm.sh;

echo "0.0.1-beta.4" > "$GITHUB_WORKSPACE/DEPLOYED"
DEPLOYED_TAG=$(cat $GITHUB_WORKSPACE/DEPLOYED)
DEPLOYED_VERSION=$(echo $DEPLOYED_TAG | xargs ) # trim
DEPLOYED_DIR=$GITHUB_WORKSPACE/deployed-fair-manager/

DEPLOYED_WITH_NODE_VERSION="lts/jod"
CURRENT_NODE_VERSION=$(nvm current)

git clone --branch $DEPLOYED_TAG https://github.com/$GITHUB_REPOSITORY.git $DEPLOYED_DIR

HARDHAT_NODE_SESSION="hardhat-node"
yarn pm2 start "yarn hardhat node" --name "$HARDHAT_NODE_SESSION"

cd $DEPLOYED_DIR
nvm install $DEPLOYED_WITH_NODE_VERSION
nvm use $DEPLOYED_WITH_NODE_VERSION
yarn install

echo "Deploy previous version"

# need to configure boot instance for deploying
if [ -n "$INFURA_API_TOKEN" ]; then
    MAINNET_ENDPOINT="https://mainnet.infura.io/v3/${INFURA_API_TOKEN}"
else
    MAINNET_ENDPOINT="https://eth.llamarpc.com"
fi
CHAIN_NAME="affectionate-immediate-pollux"

DEPLOY_OUTPUT_FILE="$GITHUB_WORKSPACE/data/deploy.txt"
export TARGET="production"
export CHAIN_NAME="$CHAIN_NAME"
export MAINNET_ENDPOINT="$MAINNET_ENDPOINT"
VERSION=$DEPLOYED_VERSION yarn hardhat run migrations/deploy.ts --network localhost > $DEPLOY_OUTPUT_FILE
# don't copy manifest file because it's stored in the temporary directory
COMMITTEE_ADDRESS=$(cat $DEPLOY_OUTPUT_FILE | grep --max-count 1 "Committee" | awk '{print $NF}')

echo "Committee address:" $COMMITTEE_ADDRESS
echo "Switch to the current version"

cd $GITHUB_WORKSPACE
nvm use $CURRENT_NODE_VERSION
rm -r --interactive=never $DEPLOYED_DIR

export ALLOW_NOT_ATOMIC_UPGRADE="OK"
export TARGET="$COMMITTEE_ADDRESS"
export ENDPOINT="http://127.0.0.1:8545"
yarn hardhat run migrations/upgradeBeta.ts --network localhost

yarn pm2 stop "$HARDHAT_NODE_SESSION"

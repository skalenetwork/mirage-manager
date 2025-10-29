#!/usr/bin/env bash

set -e

HARDHAT_NODE_SESSION="hardhat-node"
yarn pm2 start "yarn hardhat node" --name "$HARDHAT_NODE_SESSION"

echo "Node Initialized."

cleanup() {
    echo "Stopping Hardhat Node"
    yarn pm2 delete "$HARDHAT_NODE_SESSION"
    echo "SUCCESS"
}

trap cleanup EXIT

echo "Running deployment setup script for fuzzy tests."

DEPLOY_OUTPUT=$(yarn hardhat run migrations/fuzzTestsSetup.ts --network localhost)

echo "Deployed! Filtering deployment output..."

NODES_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep "Nodes: 0x" | awk '{print $2}')
STATUS_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep "Status: 0x" | awk '{print $2}')
STAKING_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep "Staking: 0x" | awk '{print $2}')
DKG_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep "DKG: 0x" | awk '{print $2}')
COMMITTEE_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep "Committee: 0x" | awk '{print $2}')
ACCESS_MANAGER_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep "FairAccessManager: 0x" | awk '{print $2}')
DEPLOYER_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep "DEPLOYER: 0x" | awk '{print $2}')

echo "Deployment successful!"

echo "Nodes address: $NODES_ADDRESS"
echo "Status address: $STATUS_ADDRESS"
echo "Staking address: $STAKING_ADDRESS"
echo "Committee address: $COMMITTEE_ADDRESS"
echo "DKG address: $DKG_ADDRESS"
echo "Access Manager address: $ACCESS_MANAGER_ADDRESS"
echo "Deployer address: $DEPLOYER_ADDRESS"

export NODES=$NODES_ADDRESS
export STATUS=$STATUS_ADDRESS
export STAKING=$STAKING_ADDRESS
export COMMITTEE=$COMMITTEE_ADDRESS
export DKG=$DKG_ADDRESS
export ACCESS_MANAGER=$ACCESS_MANAGER_ADDRESS
export DEPLOYER=$DEPLOYER_ADDRESS

forge test --rpc-url http://127.0.0.1:8545/ --mt invariant_coreInvariants -vvv
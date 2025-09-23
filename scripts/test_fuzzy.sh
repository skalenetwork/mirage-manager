#!/usr/bin/env bash

set -e

echo "Starting local Hardhat node in the background..."
yarn hardhat node --port 8545 > /dev/null 2>&1 &

# 4. Define a function to kill the node.
cleanup() {
    echo "Stopping Hardhat node (PID: $(lsof -ti :8545))..."
    kill $(lsof -ti :8545)
    sleep 15
    echo "DONE"
    lsof -ti :8545
}

trap cleanup EXIT

echo "Waiting for node to initialize..."
# 5. Wait for a few seconds to ensure the node is fully up and running.
sleep 15

# --- Deployment and Output Capture ---
echo "Running deployment script..."
# 6. Run the deployment script and capture its entire output into a variable.
DEPLOY_OUTPUT=$(yarn hardhat run migrations/fuzzyTestsSetup.ts --network localhost)

# echo $DEPLOY_OUTPUT
echo "Filtering deployment output..."

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
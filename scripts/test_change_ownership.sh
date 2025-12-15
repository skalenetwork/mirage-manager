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

echo "Running deployment setup"

# Using fuzzTestsSetup to not depend on live instances for generating nodes
DEPLOY_OUTPUT=$(yarn hardhat run migrations/fuzzTestsSetup.ts --network localhost)

echo "Deployed! Filtering deployment output..."

COMMITTEE_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep "Committee: 0x" | awk '{print $2}')

echo "Committee Address: $COMMITTEE_ADDRESS"

ALLOW_NOT_ATOMIC_UPGRADE=true TARGET=$COMMITTEE_ADDRESS NEW_OWNER="0x000000000000000000000000000000000000dEaD" \
 yarn hardhat run migrations/changeOwnership.ts --network localhost

#!/usr/bin/env bash

set -e

# This script runs invariant tests against a live SKALE chain (forked before tests start).
# It requires the following environment variables to be set manually:
# You can change the test to target a specific contract

NODES_ADDRESS="0xaddress"
STATUS_ADDRESS="0xaddress"
STAKING_ADDRESS="0xaddress"
DKG_ADDRESS="0xaddress"
COMMITTEE_ADDRESS="0xaddress"
ACCESS_MANAGER_ADDRESS="0xaddress"
DEPLOYER_ADDRESS="0xaddress"
NODE_ENDPOINT="http://endpoint.to.node/"

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

forge test --rpc-url $NODE_ENDPOINT --mt invariant_coreInvariants -vvv
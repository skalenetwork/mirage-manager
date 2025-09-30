// SPDX-License-Identifier: AGPL-3.0-only

/*
    CommitteeHandler.sol - fair-manager
    Copyright (C) 2025-Present SKALE Labs
    @author Dmytro Stebaiev

    fair-manager is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published
    by the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    fair-manager is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with fair-manager.  If not, see <https://www.gnu.org/licenses/>.
*/
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

// 1. Import Foundry's standard test library
import {RootSetup} from "../Setup.sol";

// 2. Import the contract you want to test from your 'contracts' folder
import {Committee, NodeId} from "../../contracts/Committee.sol";
import {Duration, Status} from "../../contracts/Status.sol";

// 3. Your test contract must inherit from `Test`
contract CommitteeHandler is Test {

    Committee public committee;
    NodeId[] public fixtureNode;
    constructor (address _committee) {
        committee = Committee(_committee);
        require(address(committee) != address(0), "COMMITTEE not set");
        // scans for first 256 Nodes
        for (uint256 i = 1; i < 257; i++) {
            NodeId node = NodeId.wrap(i);
            if (committee.nodes().activeNodeExists(node)) {
                fixtureNode.push(node);
            }
        }
    }

    function forceEjectNodes(uint8 numNodes) public {
        vm.warp(block.timestamp + Duration.unwrap(Status(address(committee.status())).heartbeatInterval()) + 1);
        for (uint8 i = 0; i < numNodes; i++) {
            committee.ejectUnhealthyNode();
        }
    }

    function forceEjectNode() public {
        vm.warp(block.timestamp + Duration.unwrap(Status(address(committee.status())).heartbeatInterval()) + 1);
        committee.ejectUnhealthyNode();
    }

    // can randomly simulate consensus rewards
    function paySomeConsensusRewards(uint16 nodeIndex) public {
        vm.deal(address(committee.staking()), address(committee.staking()).balance + 1 ether);
        NodeId node = fixtureNode[nodeIndex % fixtureNode.length];
        address wallet = address(committee.staking().getRewardWallet(node));
        assert(wallet != address(0));
        vm.deal(wallet, wallet.balance + 1e14);
    }

    // can simulate random time pass
    function skipTime(uint8 time) public {
        vm.warp(block.timestamp + uint256(time));
    }
}
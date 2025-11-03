// SPDX-License-Identifier: AGPL-3.0-only

/*
    CommitteeHandler.sol - fair-manager
    Copyright (C) 2025-Present SKALE Labs


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

import {CommitteeTester, NodeId} from "../../contracts/test/CommitteeTester.sol";
import {Timestamp, Committee} from "../../contracts/Committee.sol";
import {IStatus} from "../../contracts/Status.sol";
import {PoolLibrary} from "../../contracts/utils/Pool.sol";
import {Fair, IStaking} from "../../contracts/Staking.sol";
import {Duration, Status} from "../../contracts/Status.sol";

contract CommitteeHandler is Test {

    CommitteeTester public committee;
    NodeId[] public fixtureNode;
    address private admin;
    uint256 private selectCount = 0;
    constructor (address _committee, address _admin) {
        committee = CommitteeTester(_committee);
        require(address(committee) != address(0), "COMMITTEE not set");
        // scans for first 256 Nodes
        for (uint256 i = 1; i < 257; i++) {
            NodeId node = NodeId.wrap(i);
            if (committee.nodes().activeNodeExists(node)) {
                fixtureNode.push(node);
            }
        }
        admin = _admin;
        vm.prank(admin);
        committee.setCommitteeSize(5); // set as 5 for testing
    }

    function selectCommittee() public {
        vm.assume(selectCount < 5); // limit the number of committee selections
        uint256 timestamp = Timestamp.unwrap(committee.getCommittee(committee.lastCommitteeIndex()).startingTimestamp);
        uint256 selectionTimestamp = timestamp - Duration.unwrap(committee.transitionDelay());
        if (timestamp == type(uint256).max) {
            selectionTimestamp = 0;
        }
        // expect revert if called to early
        // expect revert if not enough eligible staked nodes
        uint256 eligibleNodes = 0;
        for (uint256 i = 0; i < fixtureNode.length; ++i) {
            NodeId node = fixtureNode[i];
            if(
                committee.staking().getNodeShare(node) > 0 &&
                committee.status().isWhitelisted(node) &&
                committee.status().isHealthy(node) &&
                committee.isNodeInRBTree(node)
            ){
                eligibleNodes++;
            }
        }
        if (type(uint256).max != timestamp && timestamp >= block.timestamp){
            // partialRevert only matches the selector
            vm.expectPartialRevert(Committee.CommitteeRotationInProgress.selector);
        }
        else if (eligibleNodes < committee.committeeSize()) {
            vm.expectPartialRevert(PoolLibrary.TooFewCandidates.selector);
        }
        vm.prank(admin);
        committee.select();

        // Cap the limit of committee selections
        selectCount++;
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

    function paySomeConsensusRewards(uint16 nodeIndex) public {
        vm.deal(address(committee.staking()), address(committee.staking()).balance + 1 ether);
        NodeId node = fixtureNode[nodeIndex % fixtureNode.length];
        address wallet = address(committee.staking().getRewardWallet(node));
        assert(wallet != address(0));
        vm.deal(wallet, wallet.balance + 1e14);
    }

    function skipTime(uint8 time) public {
        vm.warp(block.timestamp + uint256(time));
    }
}
// cspell:words Vitalik's

// SPDX-License-Identifier: AGPL-3.0-only

/*
    StakingHandler.sol - fair-manager
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

// 2. Import the contract you want to test from your 'contracts' folder
import {Fair, NodeId, Staking, Timestamp} from "../../contracts/Staking.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// 3. Your test contract must inherit from `Test`
contract StakingHandler is Test {
    using EnumerableSet for EnumerableSet.AddressSet;

    Staking public staking;

    // Keep track of user balances to make smarter calls
    //mapping(address => uint256) public tokenBalances;
    EnumerableSet.AddressSet private users;
    NodeId[] public fixtureNode;

    address public constant DONATOR_ADDRESS = 0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B; // Vitalik's address, has a lot of ETH
    constructor(address _staking, address) {
        staking = Staking(payable(_staking));
        require(address(staking) != address(0), "STAKING not set");

        for (uint256 i = 1; i < 257; i++) {
            NodeId node = NodeId.wrap(i);
            if (staking.nodes().activeNodeExists(node)) {
                fixtureNode.push(node);
            }
        }
    }

    function setFeeRate(uint8 feeRate, uint8 nodeIndex) public {
        NodeId node = fixtureNode[nodeIndex % fixtureNode.length];
        assert(staking.nodes().activeNodeExists(node));
        vm.assume(feeRate < staking.getNodeFeeRate(node));
        address nodeOwner = staking.nodes().getNode(node).nodeAddress;
        vm.prank(nodeOwner);
        staking.setFeeRate(feeRate);
        assert(staking.getNodeFeeRate(node) == feeRate);
    }

    function stakeFor(address user, uint8 nodeIndex, uint48 amountToStake) public {
        // 1. Pick a random user
        vm.assume(user != address(0)); // user cannot be zero address

        // Pick a random of the nodes
        NodeId node = fixtureNode[nodeIndex % fixtureNode.length];
        vm.assume(staking.nodes().activeNodeExists(node));

        // 2. Constrain inputs to valid scenarios
        address staker = user;

        // 3. Orchestrate the multi-contract call sequence
        assert(address(staking).balance + address(staking.getRewardWallet(node)).balance >= Fair.unwrap(staking.getNodeTotalStake(node)));
        vm.deal(staker, uint256(amountToStake) + 1e13); // add some extra
        vm.prank(staker);
        staking.stake{value: uint256(amountToStake) + 1e13}(node);
        users.add(staker);
    }

    function requestRetrieveAll(uint8 userIndex, uint8 nodeIndex) public {
        NodeId node = fixtureNode[nodeIndex % fixtureNode.length];
        assert(staking.nodes().activeNodeExists(node));
        Fair totalStake = staking.getNodeTotalStake(node);

        vm.assume(totalStake > Fair.wrap(0));
        address[] memory stakedUsers = staking.getDelegatorsToNode(node);
        vm.assume(stakedUsers.length > 0);

        address staker = stakedUsers[userIndex % stakedUsers.length];
        // node owners cannot retrieve
        vm.assume(staker != staking.nodes().getNode(node).nodeAddress);

        vm.prank(staker);
        staking.requestRetrieveAll(node);
    }
    // allow the fuzzer to alter picked user and node
    function requestRetrieve(uint8 userIndex, uint8 nodeIndex, uint32 amountToRetrieve) public {
        vm.assume(amountToRetrieve > 0);
        // Pick a node
        NodeId node = fixtureNode[nodeIndex % fixtureNode.length];
        assert(staking.nodes().activeNodeExists(node));
        Fair totalStake = staking.getNodeTotalStake(node);

        vm.assume(totalStake > Fair.wrap(0));
        // 1. Pick a random user
        address[] memory stakedUsers = staking.getDelegatorsToNode(node);
        vm.assume(stakedUsers.length > 0);

        address staker = stakedUsers[userIndex % stakedUsers.length];
        // node owners cannot retrieve
        vm.assume(staker != staking.nodes().getNode(node).nodeAddress);

        // 2. Constrain inputs to valid scenarios
        uint256 maxRetrievable = Fair.unwrap(staking.getStakedToNodeAmountFor(node, staker));
        assert(maxRetrievable > 0); // this is possible because stake operations are not allowed with very little stake
        vm.assume(amountToRetrieve < maxRetrievable);

        vm.prank(staker);
        staking.requestRetrieve(node, Fair.wrap(uint256(amountToRetrieve)));
    }

    function donate(uint32 donationAmount) public {
        vm.assume(donationAmount > 1e2);
        uint256 amount = uint256(donationAmount);
        vm.deal(DONATOR_ADDRESS, amount);

        vm.prank(DONATOR_ADDRESS);
        (bool success,) = address(staking).call{value: amount}("");
        require(success, "Donation call failed");
        assert(success);
    }

    /*function claimFees() public {

    }
    function claimAllFees() public {

    }*/

    function getNumNodes() external view returns (uint256 len) {
        return fixtureNode.length;
    }

    /*function retrieve() public {
        vm.warp(block.timestamp + 1);
        // 1. Pick a random user
        address staker = users[block.timestamp % users.length];

        if(Fair.unwrap(staking.getTotalInExitQueueFor(staker)) == 0) return;

        uint256 requestId = staking.getUnlockedExitRequestFor(staker, 0).requestId;

        // 3. Orchestrate the multi-contract call sequence
        uint256 beforeBalance = staker.balance;
        vm.prank(staker);
        staking.claimRequest(requestId);
        uint256 afterBalance = staker.balance;
        // 4. Update our shadow state
        tokenBalances[staker] += (afterBalance - beforeBalance);
    }*/

    // TODO: add more complex functions
}
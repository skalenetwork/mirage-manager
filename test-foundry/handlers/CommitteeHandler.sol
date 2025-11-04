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

import {Committee, Timestamp} from "../../contracts/Committee.sol";
import {Duration, Status} from "../../contracts/Status.sol";
import {CommitteeTester, NodeId} from "../../contracts/test/CommitteeTester.sol";
import {PoolLibrary} from "../../contracts/utils/Pool.sol";

import {Test} from "../../lib/forge-std/src/Test.sol";

/**
 * @title ICommitteeHandler
 * @author Eduardo Vasques
 * @notice Interface for the Committee contract testing handler
 */
interface ICommitteeHandler {
    /**
     * @notice Selects a new committee
     */
    function selectCommittee() external;

    /**
     * @notice Forces ejection of multiple unhealthy nodes
     * @param numNodes The number of nodes to attempt to eject
     */
    function forceEjectNodes(uint8 numNodes) external;

    /**
     * @notice Forces ejection of a single unhealthy node
     */
    function forceEjectNode() external;

    /**
     * @notice Simulate block rewards to a node's reward wallet and stability rewards to staking contract
     * @param nodeIndex Index of a node in the fixture node array
     */
    function paySomeConsensusRewards(uint16 nodeIndex) external;

    /**
     * @notice Skips forward in time by a specified amount
     * @param time The number of seconds to skip forward
     */
    function skipTime(uint8 time) external;

    /**
     * @notice Gets the CommitteeTester contract instance
     * @return committee The CommitteeTester contract being tested
     */
    function committee() external view returns (CommitteeTester committee);

    /**
     * @notice Gets a fixture node by index
     * @param index The index of the node in the fixture array
     * @return nodeId The NodeId at the specified index
     */
    function fixtureNode(uint256 index) external view returns (NodeId nodeId);
}

/**
 * @title Committee Handler
 * @author Eduardo Vasques
 * @notice Handler contract for testing the Committee contract
 */
contract CommitteeHandler is Test, ICommitteeHandler {

    /// @inheritdoc ICommitteeHandler
    CommitteeTester public committee;

    /// @inheritdoc ICommitteeHandler
    NodeId[] public fixtureNode;

    /// @dev The address with DEFAULT_ADMIN privileges in Fair Manager
    address private _admin;

    /// @dev Counter to track and limit the number of committee selections per test run
    uint256 private _selectCount = 0;

    error CommitteeAddressNotSet();

    /**
     * @notice Constructor
     * @param _committee The address of the CommitteeTester contract
     * @param admin The address of the project admin user
     * @dev Sets committee size to 5 for testing purposes
     * @dev Scans for first 256 active nodes to populate fixtureNode array
     */
    constructor (address _committee, address admin) {
        committee = CommitteeTester(_committee);
        require(address(committee) != address(0), CommitteeAddressNotSet());
        // scans for first 256 Nodes
        for (uint256 i = 1; i < 257; ++i) {
            NodeId node = NodeId.wrap(i);
            if (committee.nodes().activeNodeExists(node)) {
                fixtureNode.push(node);
            }
        }
        _admin = admin;
        vm.prank(_admin);
        committee.setCommitteeSize(5);
    }

    /// @inheritdoc ICommitteeHandler
    function selectCommittee() public override {
        vm.assume(_selectCount < 5); // limit the number of committee selections
        uint256 timestamp = Timestamp.unwrap(committee.getCommittee(committee.lastCommitteeIndex()).startingTimestamp);
        uint256 selectionTimestamp = timestamp - Duration.unwrap(committee.transitionDelay());
        if (timestamp == type(uint256).max) {
            selectionTimestamp = 0;
        }

        uint256 eligibleNodes = 0;
        uint256 numFixtureNodes = fixtureNode.length;
        for (uint256 i = 0; i < numFixtureNodes; ++i) {
            NodeId node = fixtureNode[i];
            if(
                committee.staking().getNodeShare(node) > 0 &&
                committee.status().isWhitelisted(node) &&
                committee.status().isHealthy(node) &&
                committee.isNodeInRBTree(node)
            ){
                ++eligibleNodes;
            }
        }

        // expect revert if called to early
        // expect revert if not enough eligible staked nodes

        // non-strict inequality optimized by the compiler - no improvement compared to strict in this case
        // solhint-disable-next-line gas-strict-inequalities
        if (type(uint256).max != timestamp && timestamp >= block.timestamp){
            // partialRevert only matches the error selector
            vm.expectPartialRevert(Committee.CommitteeRotationInProgress.selector);
        }
        else if (eligibleNodes < committee.committeeSize()) {
            vm.expectPartialRevert(PoolLibrary.TooFewCandidates.selector);
        }
        vm.prank(_admin);
        committee.select();
        ++_selectCount;
    }

    /// @inheritdoc ICommitteeHandler
    function forceEjectNodes(uint8 numNodes) public override {
        vm.warp(block.timestamp + Duration.unwrap(Status(address(committee.status())).heartbeatInterval()) + 1);
        for (uint8 i = 0; i < numNodes; ++i) {
            committee.ejectUnhealthyNode();
        }
    }

    /// @inheritdoc ICommitteeHandler
    function forceEjectNode() public override {
        vm.warp(block.timestamp + Duration.unwrap(Status(address(committee.status())).heartbeatInterval()) + 1);
        committee.ejectUnhealthyNode();
    }

    /// @inheritdoc ICommitteeHandler
    function paySomeConsensusRewards(uint16 nodeIndex) public override {
        vm.deal(address(committee.staking()), address(committee.staking()).balance + 1 ether);
        NodeId node = fixtureNode[nodeIndex % fixtureNode.length];
        address wallet = address(committee.staking().getRewardWallet(node));
        assert(wallet != address(0));
        vm.deal(wallet, wallet.balance + 1e14);
    }

    /// @inheritdoc ICommitteeHandler
    function skipTime(uint8 time) public override {
        vm.warp(block.timestamp + uint256(time));
    }
}
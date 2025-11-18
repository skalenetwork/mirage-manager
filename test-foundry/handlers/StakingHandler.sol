// SPDX-License-Identifier: AGPL-3.0-only

/*
    StakingHandler.sol - fair-manager
    Copyright (C) 2025-Present SKALE Labs
    @author Eduardo Vasques

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

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Fair, NodeId, Staking, Timestamp} from "../../contracts/Staking.sol";
import {Test} from "../../lib/forge-std/src/Test.sol";

/**
 * @title IStakingHandler
 * @author Eduardo Vasques
 * @notice Interface for the Staking contract testing handler
 */
interface IStakingHandler {
    /**
     * @notice Sets the fee rate for a node
     * @param feeRate The new fee rate (must be less than current rate)
     * @param nodeIndex Index into the fixture node array (modulo array length)
     */
    function setFeeRate(uint8 feeRate, uint8 nodeIndex) external;

    /**
     * @notice Stakes funds to a node on behalf of a user
     * @param user The address of the user staking
     * @param nodeIndex Index into the fixture node array (modulo array length)
     * @param amountToStake The amount to stake (in wei)
     */
    function stakeFor(address user, uint8 nodeIndex, uint48 amountToStake) external;

    /**
     * @notice Requests to retrieve all stake from a node for a user
     * @param userIndex Index into the stakers array for the node
     * @param nodeIndex Index into the fixture node array (modulo array length)
     */
    function requestRetrieveAll(uint8 userIndex, uint8 nodeIndex) external;

    /**
     * @notice Requests to retrieve a specific amount of stake from a node for a user
     * @param userIndex Index into the stakers array for the node
     * @param nodeIndex Index into the fixture node array (modulo array length)
     * @param amountToRetrieve The amount to retrieve (must be less than user's stake)
     */
    function requestRetrieve(uint8 userIndex, uint8 nodeIndex, uint32 amountToRetrieve) external;

    /**
     * @notice Donates funds to the staking contract to be distributed as rewards
     * @param donationAmount The amount to donate (in wei)
     */
    function donate(uint32 donationAmount) external;

    /**
     * @notice Claims a retrieval request for a user after the delay period
     * @param userIndex Index into the users set (modulo set length)
     */
    function retrieve(uint8 userIndex) external;

    /**
     * @notice Claims all earned fees for a node owner
     * @param nodeIndex Index into the fixture node array (modulo array length)
     */
    function claimAllFee(uint8 nodeIndex) external;

    /**
     * @notice Claims a specific amount of earned fees for a node owner
     * @param nodeIndex Index into the fixture node array (modulo array length)
     * @param amount The amount of fees to claim (must be <= earned fees)
     */
    function claimFee(uint8 nodeIndex, uint32 amount) external;

    /**
     * @notice Gets the number of nodes in the fixture
     * @return len The number of fixture nodes
     */
    function getNumNodes() external view returns (uint256 len);

    /**
     * @notice Gets the Staking contract instance
     * @return staking The Staking contract being tested
     */
    function staking() external view returns (Staking staking);

    /**
     * @notice Gets a fixture node by index
     * @param index The index of the node in the fixture array
     * @return nodeId The NodeId at the specified index
     */
    function fixtureNode(uint256 index) external view returns (NodeId nodeId);
}

/**
 * @title Staking Handler
 * @author Eduardo Vasques
 * @notice Handler contract for testing the Staking contract
 * @dev Scans for first 256 active nodes to populate fixtureNode array
 */
contract StakingHandler is Test, IStakingHandler {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice The address used to donate funds to the staking contract
    address public constant DONATOR_ADDRESS = 0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B;

    /// @inheritdoc IStakingHandler
    Staking public staking;

    /// @inheritdoc IStakingHandler
    NodeId[] public fixtureNode;

    /// @dev Set of users with pending requests in the exit queue
    EnumerableSet.AddressSet private _usersLeaving;

    error StakingAddressNotSet();
    error FailedToDonateToStaking();

    /**
     * @notice Constructor
     * @param _staking The address of the Staking contract
     * @param admin The address of the project admin user
     */
    constructor(address _staking, address admin) {
        staking = Staking(payable(_staking));
        require(address(staking) != address(0), StakingAddressNotSet());

        for (uint256 i = 1; i < 257; ++i) {
            NodeId node = NodeId.wrap(i);
            if (staking.nodes().activeNodeExists(node)) {
                fixtureNode.push(node);
            }
        }
        vm.prank(admin);
        staking.setRetrievingDelay(Timestamp.wrap(1)); // set to 1 second for easier testing
    }

    /// @inheritdoc IStakingHandler
    function setFeeRate(uint8 feeRate, uint8 nodeIndex) public override {
        NodeId node = fixtureNode[nodeIndex % fixtureNode.length];
        assert(staking.nodes().activeNodeExists(node));
        vm.assume(feeRate < staking.getNodeFeeRate(node));
        address nodeOwner = staking.nodes().getNode(node).nodeAddress;
        vm.prank(nodeOwner);
        staking.setFeeRate(feeRate);
        assert(staking.getNodeFeeRate(node) == feeRate);
    }

    /// @inheritdoc IStakingHandler
    function stakeFor(address user, uint8 nodeIndex, uint48 amountToStake) public override {
        // user should not be a precompile address (0x1 - 0xFFFF) or a contract
        vm.assume(user.code.length == 0);
        vm.assume(uint160(user) > 0xFFFF);
        // Pick a random of the nodes
        NodeId node = fixtureNode[nodeIndex % fixtureNode.length];
        vm.assume(staking.nodes().activeNodeExists(node));

        // Constrain inputs to valid scenarios
        address staker = user;

        vm.deal(staker, uint256(amountToStake) + 1e13); // add some extra
        vm.prank(staker);
        staking.stake{value: uint256(amountToStake) + 1e13}(node);
    }

    /// @inheritdoc IStakingHandler
    function requestRetrieveAll(uint8 userIndex, uint8 nodeIndex) public override {
        NodeId node = fixtureNode[nodeIndex % fixtureNode.length];
        assert(staking.nodes().activeNodeExists(node));
        Fair totalStake = staking.getNodeTotalStake(node);

        vm.assume(totalStake > Fair.wrap(0));
        address[] memory stakedUsers = staking.getDelegatorsToNode(node);
        vm.assume(stakedUsers.length > 0);

        address staker = stakedUsers[userIndex % stakedUsers.length];

        // node owners cannot retrieve
        vm.assume(staker != staking.nodes().getNode(node).nodeAddress);

        // TODO: FIX #247 - remove flush
        staking.getRewardWallet(node).flush();

        vm.prank(staker);
        staking.requestRetrieveAll(node);

        _usersLeaving.add(staker);
    }

    /// @inheritdoc IStakingHandler
    function requestRetrieve(uint8 userIndex, uint8 nodeIndex, uint32 amountToRetrieve) public override {
        vm.assume(amountToRetrieve > 0);
        // Pick a node
        NodeId node = fixtureNode[nodeIndex % fixtureNode.length];
        assert(staking.nodes().activeNodeExists(node));
        Fair totalStake = staking.getNodeTotalStake(node);

        vm.assume(totalStake > Fair.wrap(0));
        // Pick a random user
        address[] memory stakedUsers = staking.getDelegatorsToNode(node);
        vm.assume(stakedUsers.length > 0);

        address staker = stakedUsers[userIndex % stakedUsers.length];
        // node owners cannot retrieve
        vm.assume(staker != staking.nodes().getNode(node).nodeAddress);

        // Constrain inputs to valid scenarios
        uint256 maxRetrievable = Fair.unwrap(staking.getStakedToNodeAmountFor(node, staker));
        vm.assume(maxRetrievable > 0);
        vm.assume(amountToRetrieve < maxRetrievable);

        vm.prank(staker);
        staking.requestRetrieve(node, Fair.wrap(uint256(amountToRetrieve)));

        _usersLeaving.add(staker);
    }

    /// @inheritdoc IStakingHandler
    function donate(uint32 donationAmount) public override {
        vm.assume(donationAmount > 1e2);
        uint256 amount = uint256(donationAmount);
        vm.deal(DONATOR_ADDRESS, amount);

        vm.prank(DONATOR_ADDRESS);
        (bool success,) = address(staking).call{value: amount}("");
        require(success, FailedToDonateToStaking());
    }

    /// @inheritdoc IStakingHandler
    function retrieve(uint8 userIndex) public override {
        // Retrieving delay is set to 1 second in constructor, we skip 2
        vm.warp(block.timestamp + 2);
        vm.assume(_usersLeaving.length() > 0);
        address user = _usersLeaving.at(userIndex % _usersLeaving.length());
        uint256 requestId = staking.getUnlockedExitRequestFor(user, 0).requestId;
        vm.prank(user);
        staking.claimRequest(requestId);
        if (Fair.unwrap(staking.getTotalInExitQueueFor(user)) == 0) {
            _usersLeaving.remove(user);
        }
    }

    /// @inheritdoc IStakingHandler
    function claimAllFee(uint8 nodeIndex) public override {
        NodeId node = fixtureNode[nodeIndex % fixtureNode.length];
        assert(staking.nodes().activeNodeExists(node));
        Fair fees = staking.getEarnedFeeAmount(node);
        vm.assume(fees > Fair.wrap(0));

        // TODO: FIX #247 - remove flush
        staking.getRewardWallet(node).flush();

        address nodeOwner = staking.nodes().getNode(node).nodeAddress;
        vm.prank(nodeOwner);
        staking.requestAllFees(node);

        _usersLeaving.add(nodeOwner);
    }

    /// @inheritdoc IStakingHandler
    function claimFee(uint8 nodeIndex, uint32 amount) public override {
        NodeId node = fixtureNode[nodeIndex % fixtureNode.length];
        assert(staking.nodes().activeNodeExists(node));
        Fair fees = staking.getEarnedFeeAmount(node);
        vm.assume(fees > Fair.wrap(0));

        // No real improvement from transforming to strict - optimized by the compiler
        // solhint-disable-next-line gas-strict-inequalities
        vm.assume(Fair.unwrap(fees) >= uint256(amount) && amount != 0);
        address nodeOwner = staking.nodes().getNode(node).nodeAddress;
        vm.prank(nodeOwner);
        staking.requestFees(node, Fair.wrap(uint256(amount)));

        _usersLeaving.add(nodeOwner);
    }

    /// @inheritdoc IStakingHandler
    function getNumNodes() public view override returns (uint256 len) {
        return fixtureNode.length;
    }
}

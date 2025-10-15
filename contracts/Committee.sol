// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   Committee.sol - fair-manager
 *   Copyright (C) 2025-Present SKALE Labs
 *   @author Dmytro Stebaiev
 *
 *   fair-manager is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as published
 *   by the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   fair-manager is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with fair-manager.  If not, see <https://www.gnu.org/licenses/>.
 */

pragma solidity ^0.8.24;

import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {
    CommitteeIndex,
    ICommittee,
    Timestamp
} from "@skalenetwork/fair-manager-interfaces/ICommittee.sol";
import { DkgId, IDkg } from "@skalenetwork/fair-manager-interfaces/IDkg.sol";
import { INodes, NodeId } from "@skalenetwork/fair-manager-interfaces/INodes.sol";
import { IRewardWallet } from "@skalenetwork/fair-manager-interfaces/IRewardWallet.sol";
import { IStaking } from "@skalenetwork/fair-manager-interfaces/IStaking.sol";
import { Duration, IStatus } from "@skalenetwork/fair-manager-interfaces/IStatus.sol";

import { TypedSet } from "./structs/typed/TypedSet.sol";
import { DEFAULT_COMMITTEE_SIZE, DEFAULT_MIN_TRANSITION_DELAY, DEFAULT_TRANSITION_DELAY} from "./utils/constants.sol";
import { AddressIsZero, InvalidNodesAddress } from "./utils/errors.sol";
import { G2Operations } from "./utils/fieldOperations/G2Operations.sol";
import { FundLibrary } from "./utils/Fund.sol";
import { PoolLibrary } from "./utils/Pool.sol";
import { Precompiled } from "./utils/Precompiled.sol";
import { IRandom, Random } from "./utils/Random.sol";

/**
 * @title Committee
 * @author SKALE Labs
 * @notice Manages committee selection and rotation for the FAIR network
 * @dev Orchestrates node eligibility, committee formation, and DKG integration
 * @dev Maintains a weighted pool of eligible nodes for random, stake-weighted sampling
 */
contract Committee is AccessManagedUpgradeable, ICommittee {
    using PoolLibrary for PoolLibrary.Pool;
    using Random for IRandom.RandomGenerator;
    using TypedSet for TypedSet.NodeIdSet;

    /**
     * @dev Auxiliary structure to store committee node information
     * @dev Contains a set of node IDs for efficient O(1) membership checks
     */
    struct CommitteeAuxiliary {
        TypedSet.NodeIdSet nodes;
    }

    /// @notice Reference to the DKG contract
    IDkg public dkg;

    /// @notice Reference to the Nodes contract
    INodes public nodes;

    /// @notice Reference to the Status contract
    IStatus public status;

    /// @notice Reference to the Staking contract
    IStaking public override staking;

    /// @notice Address of the SKALE RNG contract for randomness
    address public skaleRng;

    /// @notice Mapping from committee index to committee data
    mapping (CommitteeIndex index => Committee committee) public committees;

    /// @dev Mapping from committee index to auxiliary committee data
    mapping (CommitteeIndex index => CommitteeAuxiliary committee) private _committeesAuxiliary;

    /// @notice Index of the last created committee
    CommitteeIndex public lastCommitteeIndex;

    /// @notice Number of nodes in a committee
    uint256 public committeeSize;

    /// @notice Delay before a committee becomes active after DKG completion
    Duration public transitionDelay;

    /// @notice Minimum allowed transition delay
    Duration public minTransitionDelay;

    /// @notice Version string for the committee contract
    string public version;

    /// @dev Pool of nodes for committee selection
    PoolLibrary.Pool internal _pool;

    /**
     * @notice Emitted when a node becomes eligible for committee selection
     * @param node The node that became eligible
     */
    event NodeBecomesEligible(NodeId indexed node);

    /**
     * @notice Emitted when a node loses eligibility for committee selection
     * @param node The node that lost eligibility
     */
    event NodeLosesEligibility(NodeId indexed node);

    /**
     * @notice Emitted when SKALE RNG is enabled
     * @param rng The address of the RNG contract
     */
    event SkaleRNGEnabled(address indexed rng);

    /**
     * @notice Emitted when SKALE RNG is disabled
     */
    event SkaleRNGDisabled();

    /**
     * @notice Emitted when the transition delay is updated
     * @param oldDelay The previous transition delay
     * @param newDelay The new transition delay
     */
    event TransitionDelayUpdated(Duration oldDelay, Duration newDelay);

    /**
     * @notice Emitted when the minimum transition delay is updated
     * @param oldDelay The previous minimum delay
     * @param newDelay The new minimum delay
     */
    event MinTransitionDelayUpdated(Duration oldDelay, Duration newDelay);

    /**
     * @notice Emitted when a new committee is selected
     * @param committeeIndex The index of the selected committee
     * @param nodes The array of selected node IDs
     * @param dkgId The DKG round ID for this committee
     */
    event CommitteeSelected(CommitteeIndex indexed committeeIndex, NodeId[] nodes, DkgId indexed dkgId);

    /**
     * @notice Emitted when the committee size is updated
     * @param oldSize The previous committee size
     * @param newSize The new committee size
     */
    event CommitteeSizeUpdated(uint256 indexed oldSize, uint256 indexed newSize);

    /**
     * @notice Emitted when the DKG contract address is updated
     * @param oldDkg The previous DKG contract address
     * @param newDkg The new DKG contract address
     */
    event DkgUpdated(IDkg indexed oldDkg, IDkg indexed newDkg);

    /**
     * @notice Emitted when the Nodes contract address is updated
     * @param oldNodes The previous Nodes contract address
     * @param newNodes The new Nodes contract address
     */
    event NodesUpdated(INodes indexed oldNodes, INodes indexed newNodes);

    /**
     * @notice Emitted when the Status contract address is updated
     * @param oldStatus The previous Status contract address
     * @param newStatus The new Status contract address
     */
    event StatusUpdated(IStatus indexed oldStatus, IStatus indexed newStatus);

    /**
     * @notice Emitted when the Staking contract address is updated
     * @param oldStaking The previous Staking contract address
     * @param newStaking The new Staking contract address
     */
    event StakingUpdated(IStaking indexed oldStaking, IStaking indexed newStaking);

    /**
     * @notice Emitted when a committee's DKG completes successfully
     * @param committeeIndex The index of the committee
     * @param dkgId The DKG round ID
     * @param startingTimestamp The timestamp when the committee becomes active
     */
    event CommitteeDkgCompleted(
        CommitteeIndex indexed committeeIndex,
        DkgId indexed dkgId,
        Timestamp startingTimestamp
    );

    /**
     * @notice Thrown when the sender is not the DKG contract
     * @param sender The address that attempted the call
     */
    error SenderIsNotDkg(
        address sender
    );

    /**
     * @notice Thrown when referencing a committee that doesn't exist
     * @param index The index of the non-existent committee
     */
    error CommitteeNotFound(
        CommitteeIndex index
    );

    /**
     * @notice Thrown when an invalid SKALE RNG contract is provided
     * @param rng The invalid RNG contract address
     */
    error InvalidSkaleRngContract(address rng);

    /**
     * @notice Thrown when a node is not active
     * @param node The inactive node
     */
    error NodeNotActive(NodeId node);

    /// @notice Thrown when the transition delay is too short
    error TransitionDelayTooShort();

    /// @notice Thrown when attempting to select a new committee while rotation is in progress
    error CommitteeRotationInProgress();

    /// @dev Ensures that the caller is the DKG contract
    modifier onlyDkg() {
        require(msg.sender == address(dkg), SenderIsNotDkg(msg.sender));
        _;
    }

    modifier onlyNonZeroAddress(address addr) {
        require(addr != address(0), AddressIsZero());
        _;
    }

    /**
     * @notice Initializes the Committee contract
     * @dev This function is called only once during contract deployment following the proxy pattern
     * @param initialAuthority The address of the initial access control authority
     * @param nodesAddress The address of the Nodes contract
     * @param commonPublicKey The common public key for the initial committee
     * @param nodeIds The array of node IDs for the initial committee
     */
    function initialize(
        address initialAuthority,
        INodes nodesAddress,
        IDkg.G2Point calldata commonPublicKey,
        NodeId[] calldata nodeIds
    )
        external
        initializer
        override
    {
        require(address(nodesAddress) != address(0), InvalidNodesAddress());
        __AccessManaged_init(initialAuthority);
        committeeSize = DEFAULT_COMMITTEE_SIZE;
        transitionDelay = Duration.wrap(DEFAULT_TRANSITION_DELAY);
        nodes = nodesAddress;
        skaleRng = address(0);
        minTransitionDelay = Duration.wrap(DEFAULT_MIN_TRANSITION_DELAY);
        _initializeCommittee(commonPublicKey, nodeIds);
    }

    /**
     * @notice Selects a new committee from eligible nodes
     * @dev Only callable by authorized addresses (restricted)
     * @dev Flushes rewards before selection and initiates DKG for the new committee
     * @dev Reverts if a committee rotation is already in progress
     */
    function select() external override restricted {
        require(
            _canSelectNewCommittee(),
            CommitteeRotationInProgress()
        );
        _flushReceivedRewards();
        IRandom.RandomGenerator memory generator = Random.create(_safeGetRandom());
        NodeId[] memory members = _pool.sample(committeeSize, generator);
        Committee storage committee = _createSuccessorCommittee(members);
        committee.dkg = dkg.generate(committee.nodes);
        emit CommitteeSelected(lastCommitteeIndex, committee.nodes, committee.dkg);
    }

    /**
     * @notice Sets the minimum transition delay
     * @dev Only callable by authorized addresses (restricted)
     * @param delay The new minimum transition delay
     */
    function setMinTransitionDelay(Duration delay) external override restricted {
        emit MinTransitionDelayUpdated(minTransitionDelay, delay);
        minTransitionDelay = delay;
    }

    /**
     * @notice Sets the SKALE RNG contract address
     * @dev Only callable by authorized addresses (restricted)
     * @dev Validates that the RNG contract returns a non-zero random number
     * @param newRNG The address of the new RNG contract
     */
    function setRNG(address newRNG) external override restricted onlyNonZeroAddress(newRNG) {
        skaleRng = newRNG;
        require(_safeGetRandom() > 0, InvalidSkaleRngContract(newRNG));
        emit SkaleRNGEnabled(newRNG);
    }

    /**
     * @notice Disables the SKALE RNG and falls back to block.prevrandao
     * @dev Only callable by authorized addresses (restricted)
     */
    function disableRNG() external override restricted {
        skaleRng = address(0);
        emit SkaleRNGDisabled();
    }

    /**
     * @notice Sets the DKG contract address
     * @dev Only callable by authorized addresses (restricted)
     * @param dkgAddress The address of the new DKG contract
     */
    function setDkg(IDkg dkgAddress) external override restricted onlyNonZeroAddress(address(dkgAddress)) {
        emit DkgUpdated(dkg, dkgAddress);
        dkg = dkgAddress;
    }

    /**
     * @notice Sets the Nodes contract address
     * @dev Only callable by authorized addresses (restricted)
     * @param nodesAddress The address of the new Nodes contract
     */
    function setNodes(INodes nodesAddress) external override restricted onlyNonZeroAddress(address(nodesAddress)) {
        emit NodesUpdated(nodes, nodesAddress);
        nodes = nodesAddress;
    }

    /**
     * @notice Sets the Status contract address
     * @dev Only callable by authorized addresses (restricted)
     * @dev Also updates the pool's Status reference
     * @param statusAddress The address of the new Status contract
     */
    function setStatus(IStatus statusAddress) external override restricted onlyNonZeroAddress(address(statusAddress)) {
        emit StatusUpdated(status, statusAddress);
        status = statusAddress;
        _pool.status = statusAddress;
    }

    /**
     * @notice Sets the Staking contract address
     * @dev Only callable by authorized addresses (restricted)
     * @param stakingAddress The address of the new Staking contract
     */
    function setStaking(
        IStaking stakingAddress
    )
        external
        override
        restricted
        onlyNonZeroAddress(address(stakingAddress))
    {
        emit StakingUpdated(staking, stakingAddress);
        staking = stakingAddress;
    }

    /**
     * @notice Sets the fair-manager version string
     * @dev Only callable by authorized addresses (restricted)
     * @param newVersion The new version string
     */
    function setVersion(string calldata newVersion) external override restricted {
        emit VersionUpdated(version, newVersion);
        version = newVersion;
    }

    /**
     * @notice Processes a successful DKG completion
     * @dev Only callable by the DKG contract
     * @dev Sets the committee's common public key and activation timestamp
     * @param round The DKG round ID that completed
     */
    function processSuccessfulDkg(DkgId round) external onlyDkg override {
        Committee storage committee = _getCommittee(lastCommitteeIndex);
        if (committee.dkg == round) {
            committee.commonPublicKey = dkg.getPublicKey(round);
            committee.startingTimestamp = Timestamp.wrap(block.timestamp + Duration.unwrap(transitionDelay));
            emit CommitteeDkgCompleted(lastCommitteeIndex, round, committee.startingTimestamp);
        }
    }

    /**
     * @notice Sets the committee size
     * @dev Only callable by authorized addresses (restricted)
     * @param size The new committee size
     */
    function setCommitteeSize(uint256 size) external override restricted {
        emit CommitteeSizeUpdated(committeeSize, size);
        committeeSize = size;
    }

    /**
     * @notice Sets the transition delay
     * @dev Only callable by authorized addresses (restricted)
     * @dev Delay must be greater than minTransitionDelay
     * @param delay The new transition delay
     */
    function setTransitionDelay(Duration delay) external override restricted {
        require(
            // false-positive: No real improvement in gas from replacing non-strict inequality
            // solhint-disable-next-line gas-strict-inequalities
            Duration.unwrap(delay) >= Duration.unwrap(minTransitionDelay),
            TransitionDelayTooShort()
        );
        emit TransitionDelayUpdated(transitionDelay, delay);
        transitionDelay = delay;
    }

    /**
     * @notice Called when a node is removed
     * @dev Only callable by Nodes contract (restricted)
     * @dev Removes the node from the eligible pool
     * @param node The ID of the removed node
     */
    function nodeRemoved(NodeId node) external override restricted {
        _setIneligible(node);
    }

    /**
     * @notice Called when a node is whitelisted
     * @dev Only callable by Status contract (restricted)
     * @dev Makes the node eligible if it has stake and is healthy
     * @param node The ID of the whitelisted node
     */
    function nodeWhitelisted(NodeId node) external override restricted {
        if (staking.getNodeTotalStake(node) > FundLibrary.ZERO_FAIR && status.isHealthy(node)) {
            _setEligible(node);
        }
    }

    /**
     * @notice Called when a node is blacklisted
     * @dev Only callable by Status contract (restricted)
     * @dev Removes the node from the eligible pool
     * @param node The ID of the blacklisted node
     */
    function nodeRemovedFromWhitelist(NodeId node) external override restricted {
        _setIneligible(node);
    }

    /**
     * @notice Processes a heartbeat from a node
     * @dev Only callable by Status contract (restricted)
     * @dev Updates node weight in the pool or makes it eligible if conditions are met
     * @dev Ejects unhealthy nodes after processing
     * @param node The ID of the node sending the heartbeat
     */
    function processHeartbeat(NodeId node) external override restricted {
        if (_isEligible(node)) {
            _pool.moveToFront(
                node,
                _shareToWeight(staking.getNodeShare(node))
            );
        } else {
            if (status.isWhitelisted(node) && staking.getNodeTotalStake(node) > FundLibrary.ZERO_FAIR) {
                _setEligible(node);
                _pool.moveToFront(
                    node,
                    _shareToWeight(staking.getNodeShare(node))
                );
            }
        }

        ejectUnhealthyNode();
    }

    /**
     * @notice Updates a node's weight in the eligible pool
     * @dev Only callable by Staking contract (restricted)
     * @dev Adds, updates, or removes the node based on weight and whitelist status
     * @param node The ID of the node
     * @param share The node's share (converted to weight)
     */
    function updateWeight(NodeId node, uint256 share) external override restricted {
        _updateWeight(node, share, status.isWhitelisted(node));
    }

    /**
     * @notice Gets the committee information for a specific index
     * @dev Reverts if the committee doesn't exist
     * @param committeeIndex The index of the committee to query
     * @return committee The committee information
     */
    function getCommittee(
        CommitteeIndex committeeIndex
    )
        external
        view
        override
        returns (Committee memory committee)
    {
        require (_committeeExists(committeeIndex), CommitteeNotFound(committeeIndex));
        return committees[committeeIndex];
    }

    /**
     * @notice Checks if a node is in the current or next committee
     * @dev Returns true if the node is found in either the current or next committee
     * @param node The node ID to check
     * @return result True if the node is in current or next committee, false otherwise
     */
    function isNodeInCurrentOrNextCommittee(NodeId node) external view override returns (bool result) {
        uint256 upperBound = 1 + CommitteeIndex.unwrap(lastCommitteeIndex);
        for (
            uint256 i = CommitteeIndex.unwrap(getActiveCommitteeIndex());
            i < upperBound;
            ++i
        ) {
            CommitteeIndex committeeIndex = CommitteeIndex.wrap(i);
            if (_committeesAuxiliary[committeeIndex].nodes.contains(node)) {
                return true;
            }
        }
        return false;
    }

    // Public

    /**
     * @notice Ejects an unhealthy node from the eligible pool
     * @dev Checks the oldest node in the pool and removes it if unhealthy
     * @dev Returns early if the pool is empty. Only affects nodes that are not healthy.
     */
    function ejectUnhealthyNode() public override {
        if (_pool.length() == 0) {
            return;
        }
        NodeId oldest = _pool.getOldestIsh();
        if (!status.isHealthy(oldest)) {
            _setIneligible(oldest);
        }
    }

    /**
     * @notice Gets the index of the currently active committee
     * @dev Iterates backwards from the last committee to find the one that has started
     * @return committeeIndex The index of the active committee
     */
    function getActiveCommitteeIndex() public view override returns (CommitteeIndex committeeIndex) {
        committeeIndex = lastCommitteeIndex;
        while (Timestamp.wrap(block.timestamp) < _getCommittee(committeeIndex).startingTimestamp) {
            committeeIndex = _previous(committeeIndex);
        }
    }

    // Private

    /**
     * @notice Creates a new committee structure with the given nodes
     * @dev Clears any existing data at the provided index because it may be overwritten
     * @param nodes_ The array of node IDs to include in the committee
     * @param index The committee index to assign
     * @return committee The created committee storage reference
     */
    function _createCommittee(NodeId[] memory nodes_, CommitteeIndex index)
        private
        returns (Committee storage committee)
    {
        lastCommitteeIndex = index;
        committees[index] = Committee({
            nodes: new NodeId[](0),
            dkg: DkgId.wrap(0),
            commonPublicKey: G2Operations.getG2Zero(),
            startingTimestamp: Timestamp.wrap(type(uint256).max)
        });
        // Clean all auxiliary fields because function may override existing committee
        _committeesAuxiliary[index].nodes.clear();

        committee = committees[index];
        CommitteeAuxiliary storage committeeAuxiliary = _committeesAuxiliary[index];
        uint256 committeeSize_ = committeeSize;
        for (uint256 i = 0; i < committeeSize_; ++i) {
            committee.nodes.push(nodes_[i]);
            assert(committeeAuxiliary.nodes.add(nodes_[i]));
        }
        return committee;
    }

    /**
     * @notice Creates the next committee in the sequence
     * @dev Calls _createCommittee with the next committee index after the currently active one
     * @param nodes_ The array of node IDs to include in the successor committee
     * @return committee The created committee storage reference
     */
    function _createSuccessorCommittee(NodeId[] memory nodes_)
        private
        returns (Committee storage committee)
    {
        return _createCommittee(nodes_, _next(getActiveCommitteeIndex()));
    }

    /**
     * @notice Initializes a committee with DKG results
     * @dev Sets the common public key and starting timestamp for the committee
     * @param commonPublicKey The common public key generated by DKG
     * @param nodeIds The array of node IDs that participated in DKG
     */
    function _initializeCommittee(
        IDkg.G2Point memory commonPublicKey,
        NodeId[] memory nodeIds
    ) private {
        committeeSize = nodeIds.length;
        for (uint256 i = 0; i < committeeSize; ++i) {
            // We know that number of nodes is reasonable small
            // and this loop is executed only once on initialization
            // so we disable the check to not over complicate the Node's code
            // slither-disable-next-line calls-loop
            require(nodes.activeNodeExists(nodeIds[i]), NodeNotActive(nodeIds[i]));
        }
        Committee storage initialCommittee =
            _createCommittee(nodeIds, CommitteeIndex.wrap(0));
        initialCommittee.commonPublicKey = commonPublicKey;
        initialCommittee.startingTimestamp = Timestamp.wrap(block.timestamp);
    }

    /**
     * @notice Marks a node as eligible and adds it to the pool
     * @dev Emits NodeBecomesEligible and enables the node in staking if not already enabled
     * @param node The node ID to mark as eligible
     */
    function _setEligible(NodeId node) private {
        _pool.add(node);
        emit NodeBecomesEligible(node);
        if (!staking.isNodeEnabled(node)) {
            staking.enable(node);
        }
    }

    /**
     * @notice Marks a node as ineligible and removes it from the pool
     * @dev Emits NodeLosesEligibility if removed and disables the node in staking if enabled
     * @param node The node ID to mark as ineligible
     */
    function _setIneligible(NodeId node) private {
        if (_pool.remove(node)) {
            emit NodeLosesEligibility(node);
        }
        if (staking.isNodeEnabled(node)) {
            staking.disable(node);
        }
    }

    /**
     * @notice Updates a node's weight in the pool based on share and whitelist status
     * @dev Adds node if whitelisted and has weight, updates existing weight, or removes if weight is zero
     * @param node The node ID to update
     * @param share The staking share amount
     * @param isWhitelisted Whether the node is currently whitelisted
     */
    function _updateWeight(NodeId node, uint256 share, bool isWhitelisted) private {
        uint256 weight = _shareToWeight(share);
        if (weight > 0) {
            if (_pool.contains(node)) {
                _pool.setWeight(node, weight);
            } else if (isWhitelisted) {
                _pool.add(node);
                emit NodeBecomesEligible(node);
            }
        } else {
            if (_pool.remove(node)) {
                emit NodeLosesEligibility(node);
            }
        }
    }

    /**
     * @notice Updates weights for committee members who have received block rewards
     * @dev Iterates through active committee and updates weights for nodes with pending rewards
     */
    function _flushReceivedRewards() private {
        Committee storage activeCommittee = _getCommittee(getActiveCommitteeIndex());
        uint256 committeeSize_ = activeCommittee.nodes.length;
        // Block creation rewards are sent to reward wallets
        // without executing smart contract code
        // because of that we have to update weights
        // to properly select the next committee
        // The loop does external calls
        // but number of iterations is reasonably small
        // slither-disable-start calls-loop
        for (uint256 i = 0; i < committeeSize_; ++i) {
            NodeId node = activeCommittee.nodes[i];
            IRewardWallet rewardWallet = staking.getRewardWallet(node);
            if (address(rewardWallet).balance > 0) {
                _updateWeight(
                    node,
                    staking.getNodeShare(node),
                    status.isWhitelisted(node)
                );
            }
        }
        // slither-disable-end calls-loop
    }

    /**
     * @notice Checks if a node is in the pool of eligible nodes
     * @dev Returns true if the node is currently in the eligible pool
     * @param node The node ID to check
     * @return eligible True if the node is eligible, false otherwise
     */
    function _isEligible(NodeId node) private view returns (bool eligible) {
        return _pool.contains(node);
    }

    /**
     * @notice Gets the committee at the specified index
     * @dev Returns storage reference to the committee data
     * @param index The committee index to retrieve
     * @return committee The committee storage reference
     */
    function _getCommittee(CommitteeIndex index) private view returns (Committee storage committee) {
        return committees[index];
    }

    /**
     * @notice Checks if a committee exists at the given index
     * @dev Committee exists if its index is not greater than the last committee index
     * @param index The committee index to check
     * @return exists True if the committee exists, false otherwise
     */
    function _committeeExists(CommitteeIndex index) private view returns (bool exists) {
        // false-positive: No real improvement in gas from replacing non-strict inequality
        // solhint-disable-next-line gas-strict-inequalities
        return CommitteeIndex.unwrap(lastCommitteeIndex) >= CommitteeIndex.unwrap(index);
    }

    /**
     * @notice Safely retrieves a random number from SKALE RNG or fallback
     * @dev Uses SKALE RNG if configured, otherwise falls back to block.prevrandao
     * @return randomNumber The random number for committee selection
     */
    function _safeGetRandom() private view returns (uint256 randomNumber) {
        if (skaleRng == address(0)) {
            return block.prevrandao;
        }
        return Precompiled.getRandomNumber(skaleRng);
    }

    /**
     * @notice Checks if a new committee can be selected
     * @dev Returns true if the latest committee is uninitialized or has already started
     * @return canSelect True if a new committee can be selected, false otherwise
     */
    function _canSelectNewCommittee() private view returns (bool canSelect) {
        Committee memory latestCommittee = _getCommittee(lastCommitteeIndex);
        return Timestamp.unwrap(latestCommittee.startingTimestamp) == type(uint256).max ||
            latestCommittee.startingTimestamp < Timestamp.wrap(block.timestamp);
    }

    /**
     * @notice Calculates the next committee index
     * @dev Increments the committee index by one
     * @param index The current committee index
     * @return nextIndex The next committee index
     */
    function _next(CommitteeIndex index) private pure returns (CommitteeIndex nextIndex) {
        return CommitteeIndex.wrap(CommitteeIndex.unwrap(index) + 1);
    }

    /**
     * @notice Calculates the previous committee index
     * @dev Decrements the committee index by one
     * @param index The current committee index
     * @return nextIndex The previous committee index
     */
    function _previous(CommitteeIndex index) private pure returns (CommitteeIndex nextIndex) {
        return CommitteeIndex.wrap(CommitteeIndex.unwrap(index) - 1);
    }

    /**
     * @notice Converts a node's staking share to a weight value
     * @dev Currently a 1:1 mapping; returns the share as the weight. Future adjustments are possible.
     * @param share The staking share amount
     * @return weight The calculated weight for committee selection
     */
    function _shareToWeight(uint256 share) private pure returns (uint256 weight)
    {
        return share;
    }

}

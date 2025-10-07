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

import { AccessManagedUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { CommitteeIndex, ICommittee, Timestamp } from "@skalenetwork/fair-manager-interfaces/ICommittee.sol";
import { DkgId, IDkg } from "@skalenetwork/fair-manager-interfaces/IDkg.sol";
import { INodes, NodeId } from "@skalenetwork/fair-manager-interfaces/INodes.sol";
import { IRewardWallet } from "@skalenetwork/fair-manager-interfaces/IRewardWallet.sol";
import { IStaking } from "@skalenetwork/fair-manager-interfaces/IStaking.sol";
import { Duration, IStatus } from "@skalenetwork/fair-manager-interfaces/IStatus.sol";

import { TypedSet } from "./structs/typed/TypedSet.sol";
import { G2Operations } from "./utils/fieldOperations/G2Operations.sol";
import { FundLibrary } from "./utils/Fund.sol";
import { PoolLibrary } from "./utils/Pool.sol";
import { Precompiled } from "./utils/Precompiled.sol";
import { IRandom, Random } from "./utils/Random.sol";

/**
 * @title Committee
 * @notice Manages the committee of nodes, their selection, and lifecycle.
 */
contract Committee is AccessManagedUpgradeable, ICommittee {

    using PoolLibrary for PoolLibrary.Pool;
    using Random for IRandom.RandomGenerator;
    using TypedSet for TypedSet.NodeIdSet;

    struct CommitteeAuxiliary {
        TypedSet.NodeIdSet nodes;
    }

    /// @notice The DKG contract instance.
    IDkg public dkg;
    /// @notice The Nodes contract instance.
    INodes public nodes;
    /// @notice The Status contract instance.
    IStatus public status;
    /// @notice The Staking contract instance.
    IStaking public override staking;
    /// @notice The address of the Skale RNG contract.
    address public skaleRng;

    /// @notice Mapping from committee index to committee data.
    mapping(CommitteeIndex index => Committee committee) public committees;
    mapping(CommitteeIndex index => CommitteeAuxiliary committee) private _committeesAuxiliary;
    /// @notice The index of the last created committee.
    CommitteeIndex public lastCommitteeIndex;
    /// @notice The size of the committee.
    uint256 public committeeSize;
    /// @notice The delay for a committee transition.
    Duration public transitionDelay;
    /// @notice The minimum delay for a committee transition.
    Duration public minTransitionDelay;
    /// @notice The version of the contract.
    string public version;

    PoolLibrary.Pool internal _pool;

    /**
     * @notice Emitted when a node becomes eligible for committee selection.
     * @param node The ID of the node that became eligible.
     */
    event NodeBecomesEligible(NodeId indexed node);
    /**
     * @notice Emitted when a node loses eligibility for committee selection.
     * @param node The ID of the node that lost eligibility.
     */
    event NodeLosesEligibility(NodeId indexed node);
    /**
     * @notice Emitted when the Skale RNG contract is enabled.
     * @param rng The address of the Skale RNG contract.
     */
    event SkaleRNGEnabled(address indexed rng);
    /// @notice Emitted when the Skale RNG contract is disabled.
    event SkaleRNGDisabled();
    /**
     * @notice Emitted when the transition delay is updated.
     * @param oldDelay The old transition delay.
     * @param newDelay The new transition delay.
     */
    event TransitionDelayUpdated(Duration oldDelay, Duration newDelay);
    /**
     * @notice Emitted when the minimum transition delay is updated.
     * @param oldDelay The old minimum transition delay.
     * @param newDelay The new minimum transition delay.
     */
    event MinTransitionDelayUpdated(Duration oldDelay, Duration newDelay);
    /**
     * @notice Emitted when a new committee is selected.
     * @param committeeIndex The index of the selected committee.
     * @param nodes The array of node IDs in the committee.
     * @param dkgId The DKG ID associated with the committee.
     */
    event CommitteeSelected(CommitteeIndex indexed committeeIndex, NodeId[] nodes, DkgId indexed dkgId);
    /**
     * @notice Emitted when the committee size is updated.
     * @param oldSize The old committee size.
     * @param newSize The new committee size.
     */
    event CommitteeSizeUpdated(uint256 indexed oldSize, uint256 indexed newSize);
    /**
     * @notice Emitted when the DKG contract address is updated.
     * @param oldDkg The old DKG contract address.
     * @param newDkg The new DKG contract address.
     */
    event DkgUpdated(IDkg indexed oldDkg, IDkg indexed newDkg);
    /**
     * @notice Emitted when the Nodes contract address is updated.
     * @param oldNodes The old Nodes contract address.
     * @param newNodes The new Nodes contract address.
     */
    event NodesUpdated(INodes indexed oldNodes, INodes indexed newNodes);
    /**
     * @notice Emitted when the Status contract address is updated.
     * @param oldStatus The old Status contract address.
     * @param newStatus The new Status contract address.
     */
    event StatusUpdated(IStatus indexed oldStatus, IStatus indexed newStatus);
    /**
     * @notice Emitted when the Staking contract address is updated.
     * @param oldStaking The old Staking contract address.
     * @param newStaking The new Staking contract address.
     */
    event StakingUpdated(IStaking indexed oldStaking, IStaking indexed newStaking);
    /**
     * @notice Emitted when a committee's DKG process is completed.
     * @param committeeIndex The index of the committee.
     * @param dkgId The DKG ID.
     * @param startingTimestamp The starting timestamp of the committee.
     */
    event CommitteeDkgCompleted(
        CommitteeIndex indexed committeeIndex, DkgId indexed dkgId, Timestamp startingTimestamp
    );

    error SenderIsNotDkg(address sender);
    error CommitteeNotFound(CommitteeIndex index);
    error InvalidSkaleRngContract(address rng);
    error NodeNotActive(NodeId node);
    error TransitionDelayTooShort();
    error CommitteeRotationInProgress();

    modifier onlyDkg() {
        require(msg.sender == address(dkg), SenderIsNotDkg(msg.sender));
        _;
    }

    /**
     * @notice Initializes the Committee contract.
     * @param initialAuthority The address of the initial authority.
     * @param nodesAddress The address of the Nodes contract.
     * @param commonPublicKey The common public key for the initial committee.
     * @param nodeIds The array of node IDs for the initial committee.
     */
    function initialize(
        address initialAuthority,
        INodes nodesAddress,
        IDkg.G2Point calldata commonPublicKey,
        NodeId[] calldata nodeIds
    )
        external
        override
        initializer
    {
        __AccessManaged_init(initialAuthority);
        committeeSize = 22;
        transitionDelay = Duration.wrap(1 days);
        nodes = nodesAddress;
        skaleRng = address(0);
        minTransitionDelay = Duration.wrap(10 minutes);
        _initializeCommittee(commonPublicKey, nodeIds);
    }

    /**
     * @notice Selects a new committee using weighted-random selection.
     */
    function select() external override restricted {
        require(_canSelectNewCommittee(), CommitteeRotationInProgress());
        _flushReceivedRewards();
        IRandom.RandomGenerator memory generator = Random.create(_safeGetRandom());
        NodeId[] memory members = _pool.sample(committeeSize, generator);
        Committee storage committee = _createSuccessorCommittee(members);
        committee.dkg = dkg.generate(committee.nodes);
        emit CommitteeSelected(lastCommitteeIndex, committee.nodes, committee.dkg);
    }

    /**
     * @notice Sets the minimum transition delay for committee rotation.
     * @param delay The new minimum transition delay.
     */
    function setMinTransitionDelay(Duration delay) external override restricted {
        emit MinTransitionDelayUpdated(minTransitionDelay, delay);
        minTransitionDelay = delay;
    }

    /**
     * @notice Sets the address of the Skale RNG contract.
     * @param newRNG The address of the new RNG contract.
     */
    function setRNG(address newRNG) external override restricted {
        require(newRNG != address(0), InvalidSkaleRngContract(newRNG));
        skaleRng = newRNG;
        require(_safeGetRandom() > 0, InvalidSkaleRngContract(newRNG));
        emit SkaleRNGEnabled(newRNG);
    }

    /**
     * @notice Disables the Skale RNG contract.
     */
    function disableRNG() external override restricted {
        skaleRng = address(0);
        emit SkaleRNGDisabled();
    }

    /**
     * @notice Sets the address of the DKG contract.
     * @param dkgAddress The address of the new DKG contract.
     */
    function setDkg(IDkg dkgAddress) external override restricted {
        emit DkgUpdated(dkg, dkgAddress);
        dkg = dkgAddress;
    }

    /**
     * @notice Sets the address of the Nodes contract.
     * @param nodesAddress The address of the new Nodes contract.
     */
    function setNodes(INodes nodesAddress) external override restricted {
        emit NodesUpdated(nodes, nodesAddress);
        nodes = nodesAddress;
    }

    /**
     * @notice Sets the address of the Status contract.
     * @param statusAddress The address of the new Status contract.
     */
    function setStatus(IStatus statusAddress) external override restricted {
        emit StatusUpdated(status, statusAddress);
        status = statusAddress;
        _pool.status = statusAddress;
    }

    /**
     * @notice Sets the address of the Staking contract.
     * @param stakingAddress The address of the new Staking contract.
     */
    function setStaking(IStaking stakingAddress) external override restricted {
        emit StakingUpdated(staking, stakingAddress);
        staking = stakingAddress;
    }

    /**
     * @notice Sets the version of the contract.
     * @param newVersion The new version string.
     */
    function setVersion(string calldata newVersion) external override restricted {
        emit VersionUpdated(version, newVersion);
        version = newVersion;
    }

    /**
     * @notice Processes a successful DKG round.
     * @param round The ID of the DKG round that has been successfully completed.
     */
    function processSuccessfulDkg(DkgId round) external override onlyDkg {
        Committee storage committee = _getCommittee(lastCommitteeIndex);
        if (committee.dkg == round) {
            committee.commonPublicKey = dkg.getPublicKey(round);
            committee.startingTimestamp = Timestamp.wrap(block.timestamp + Duration.unwrap(transitionDelay));
            emit CommitteeDkgCompleted(lastCommitteeIndex, round, committee.startingTimestamp);
        }
    }

    /**
     * @notice Sets the size of the committee.
     * @param size The new size of the committee.
     */
    function setCommitteeSize(uint256 size) external override restricted {
        emit CommitteeSizeUpdated(committeeSize, size);
        committeeSize = size;
    }

    /**
     * @notice Sets the transition delay for committee rotation.
     * @param delay The new transition delay.
     */
    function setTransitionDelay(Duration delay) external override restricted {
        require(Duration.unwrap(delay) + 1 > Duration.unwrap(minTransitionDelay), TransitionDelayTooShort());
        emit TransitionDelayUpdated(transitionDelay, delay);
        transitionDelay = delay;
    }

    /**
     * @notice Called when a node is removed.
     * @param node The ID of the removed node.
     */
    function nodeRemoved(NodeId node) external override restricted {
        _setIneligible(node);
    }

    /**
     * @notice Called when a node is whitelisted.
     * @param node The ID of the whitelisted node.
     */
    function nodeWhitelisted(NodeId node) external override restricted {
        if (staking.getNodeTotalStake(node) > FundLibrary.ZERO_FAIR && status.isHealthy(node)) {
            _setEligible(node);
        }
    }

    /**
     * @notice Called when a node is blacklisted.
     * @param node The ID of the blacklisted node.
     */
    function nodeBlacklisted(NodeId node) external override restricted {
        _setIneligible(node);
    }

    /**
     * @notice Processes a heartbeat from a node.
     * @param node The ID of the node that sent the heartbeat.
     */
    function processHeartbeat(NodeId node) external override restricted {
        if (_isEligible(node)) {
            _pool.moveToFront(node, _shareToWeight(staking.getNodeShare(node)));
        } else {
            if (status.isWhitelisted(node) && staking.getNodeTotalStake(node) > FundLibrary.ZERO_FAIR) {
                _setEligible(node);
                _pool.moveToFront(node, _shareToWeight(staking.getNodeShare(node)));
            }
        }

        ejectUnhealthyNode();
    }

    /**
     * @notice Updates the weight of a node.
     * @param node The ID of the node to update.
     * @param share The new share of the node.
     */
    function updateWeight(NodeId node, uint256 share) external override restricted {
        _updateWeight(node, share, status.isWhitelisted(node));
    }

    /**
     * @notice Retrieves the details of a specific committee.
     * @param committeeIndex The index of the committee to retrieve.
     * @return committee The committee details.
     */
    function getCommittee(CommitteeIndex committeeIndex) external view override returns (Committee memory committee) {
        require(_committeeExists(committeeIndex), CommitteeNotFound(committeeIndex));
        return committees[committeeIndex];
    }

    /**
     * @notice Checks if a node is part of the current or next committee.
     * @param node The ID of the node to check.
     * @return result True if the node is in the current or next committee, false otherwise.
     */
    function isNodeInCurrentOrNextCommittee(NodeId node) external view override returns (bool result) {
        for (
            uint256 i = CommitteeIndex.unwrap(getActiveCommitteeIndex());
            i < 1 + CommitteeIndex.unwrap(lastCommitteeIndex);
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
     * @notice Ejects an unhealthy node from the selection pool.
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
     * @notice Retrieves the index of the currently active committee.
     * @return committeeIndex The index of the active committee.
     */
    function getActiveCommitteeIndex() public view override returns (CommitteeIndex committeeIndex) {
        committeeIndex = lastCommitteeIndex;
        while (Timestamp.wrap(block.timestamp) < _getCommittee(committeeIndex).startingTimestamp) {
            committeeIndex = _previous(committeeIndex);
        }
    }

    // Private

    /**
     * @notice Creates a new committee.
     * @param nodes_ The array of node IDs for the new committee.
     * @param index The index of the new committee.
     * @return committee The newly created committee.
     */
    function _createCommittee(
        NodeId[] memory nodes_,
        CommitteeIndex index
    )
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
     * @notice Creates a successor committee.
     * @param nodes_ The array of node IDs for the new committee.
     * @return committee The newly created committee.
     */
    function _createSuccessorCommittee(NodeId[] memory nodes_) private returns (Committee storage committee) {
        return _createCommittee(nodes_, _next(getActiveCommitteeIndex()));
    }

    /**
     * @notice Initializes the first committee.
     * @param commonPublicKey The common public key for the initial committee.
     * @param nodeIds The array of node IDs for the initial committee.
     */
    function _initializeCommittee(IDkg.G2Point memory commonPublicKey, NodeId[] memory nodeIds) private {
        committeeSize = nodeIds.length;
        for (uint256 i = 0; i < committeeSize; ++i) {
            // We know that number of nodes is reasonable small
            // and this loop is executed only once on initialization
            // so we disable the check to not over complicate the Node's code
            // slither-disable-next-line calls-loop
            require(nodes.activeNodeExists(nodeIds[i]), NodeNotActive(nodeIds[i]));
        }
        Committee storage initialCommittee = _createCommittee(nodeIds, CommitteeIndex.wrap(0));
        initialCommittee.commonPublicKey = commonPublicKey;
        initialCommittee.startingTimestamp = Timestamp.wrap(block.timestamp);
    }

    /**
     * @notice Sets a node as eligible for committee selection.
     * @param node The ID of the node.
     */
    function _setEligible(NodeId node) private {
        _pool.add(node);
        emit NodeBecomesEligible(node);
        if (!staking.isNodeEnabled(node)) {
            staking.enable(node);
        }
    }

    /**
     * @notice Sets a node as ineligible for committee selection.
     * @param node The ID of the node.
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
     * @notice Updates the weight of a node.
     * @param node The ID of the node to update.
     * @param share The new share of the node.
     * @param isWhitelisted True if the node is whitelisted, false otherwise.
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
     * @notice Flushes received rewards for the active committee.
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
                _updateWeight(node, staking.getNodeShare(node), status.isWhitelisted(node));
            }
        }
        // slither-disable-end calls-loop
    }

    /**
     * @notice Checks if a node is eligible for committee selection.
     * @param node The ID of the node to check.
     * @return eligible True if the node is eligible, false otherwise.
     */
    function _isEligible(NodeId node) private view returns (bool eligible) {
        return _pool.contains(node);
    }

    /**
     * @notice Retrieves the details of a specific committee.
     * @param index The index of the committee to retrieve.
     * @return committee The committee details.
     */
    function _getCommittee(CommitteeIndex index) private view returns (Committee storage committee) {
        return committees[index];
    }

    /**
     * @notice Checks if a committee exists.
     * @param index The index of the committee to check.
     * @return exists True if the committee exists, false otherwise.
     */
    function _committeeExists(CommitteeIndex index) private view returns (bool exists) {
        return !(CommitteeIndex.unwrap(lastCommitteeIndex) < CommitteeIndex.unwrap(index));
    }

    /**
     * @notice Retrieves a random number from the Skale RNG contract or the block's prevrandao.
     * @return randomNumber The random number.
     */
    function _safeGetRandom() private view returns (uint256 randomNumber) {
        if (skaleRng == address(0)) {
            return block.prevrandao;
        }
        return Precompiled.getRandomNumber(skaleRng);
    }

    /**
     * @notice Checks if a new committee can be selected.
     * @return canSelect True if a new committee can be selected, false otherwise.
     */
    function _canSelectNewCommittee() private view returns (bool canSelect) {
        Committee memory latestCommittee = _getCommittee(lastCommitteeIndex);
        return Timestamp.unwrap(latestCommittee.startingTimestamp) == type(uint256).max
            || latestCommittee.startingTimestamp < Timestamp.wrap(block.timestamp);
    }

    /**
     * @notice Retrieves the next committee index.
     * @param index The current committee index.
     * @return nextIndex The next committee index.
     */
    function _next(CommitteeIndex index) private pure returns (CommitteeIndex nextIndex) {
        return CommitteeIndex.wrap(CommitteeIndex.unwrap(index) + 1);
    }

    /**
     * @notice Retrieves the previous committee index.
     * @param index The current committee index.
     * @return nextIndex The previous committee index.
     */
    function _previous(CommitteeIndex index) private pure returns (CommitteeIndex nextIndex) {
        return CommitteeIndex.wrap(CommitteeIndex.unwrap(index) - 1);
    }

    /**
     * @notice Converts a share to a weight.
     * @param share The share to convert.
     * @return weight The weight.
     */
    function _shareToWeight(uint256 share) private pure returns (uint256 weight) {
        return share;
    }

}

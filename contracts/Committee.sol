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


contract Committee is AccessManagedUpgradeable, ICommittee {
    using PoolLibrary for PoolLibrary.Pool;
    using Random for IRandom.RandomGenerator;
    using TypedSet for TypedSet.NodeIdSet;

    struct CommitteeAuxiliary {
        TypedSet.NodeIdSet nodes;
    }

    IDkg public dkg;
    INodes public nodes;
    IStatus public status;
    IStaking public override staking;
    address public skaleRng;

    mapping (CommitteeIndex index => Committee committee) public committees;
    mapping (CommitteeIndex index => CommitteeAuxiliary committee) private _committeesAuxiliary;
    CommitteeIndex public lastCommitteeIndex;
    uint256 public committeeSize;
    Duration public transitionDelay;
    Duration public minTransitionDelay;
    string public version;

    PoolLibrary.Pool private _pool;

    event NodeBecomesEligible(NodeId indexed node);
    event NodeLosesEligibility(NodeId indexed node);
    event SkaleRNGEnabled(address indexed rng);
    event SkaleRNGDisabled();
    event TransitionDelayUpdated(Duration oldDelay, Duration newDelay);
    event MinTransitionDelayUpdated(Duration oldDelay, Duration newDelay);
    event CommitteeSelected(CommitteeIndex indexed committeeIndex, NodeId[] nodes, DkgId indexed dkgId);
    event CommitteeSizeUpdated(uint256 indexed oldSize, uint256 indexed newSize);
    event DkgUpdated(IDkg indexed oldDkg, IDkg indexed newDkg);
    event NodesUpdated(INodes indexed oldNodes, INodes indexed newNodes);
    event StatusUpdated(IStatus indexed oldStatus, IStatus indexed newStatus);
    event StakingUpdated(IStaking indexed oldStaking, IStaking indexed newStaking);
    event CommitteeDkgCompleted(
        CommitteeIndex indexed committeeIndex,
        DkgId indexed dkgId,
        Timestamp startingTimestamp
    );

    error SenderIsNotDkg(
        address sender
    );
    error CommitteeNotFound(
        CommitteeIndex index
    );
    error InvalidSkaleRngContract(address rng);
    error NodeNotActive(NodeId node);
    error TransitionDelayTooShort();
    error CommitteeRotationInProgress();

    modifier onlyDkg() {
        require(msg.sender == address(dkg), SenderIsNotDkg(msg.sender));
        _;
    }

    modifier onlyNonZeroAddress(address addr) {
        require(addr != address(0), AddressIsZero());
        _;
    }

    function initialize(
        address initialAuthority,
        INodes nodesAddress,
        IDkg.G2Point memory commonPublicKey,
        NodeId[] memory nodeIds
    )
        public
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

    function setMinTransitionDelay(Duration delay) external override restricted {
        emit MinTransitionDelayUpdated(minTransitionDelay, delay);
        minTransitionDelay = delay;
    }

    function setRNG(address newRNG) external override restricted onlyNonZeroAddress(newRNG) {
        skaleRng = newRNG;
        require(_safeGetRandom() > 0, InvalidSkaleRngContract(newRNG));
        emit SkaleRNGEnabled(newRNG);
    }

    function disableRNG() external override restricted {
        skaleRng = address(0);
        emit SkaleRNGDisabled();
    }

    function setDkg(IDkg dkgAddress) external override restricted onlyNonZeroAddress(address(dkgAddress)) {
        emit DkgUpdated(dkg, dkgAddress);
        dkg = dkgAddress;
    }

    function setNodes(INodes nodesAddress) external override restricted onlyNonZeroAddress(address(nodesAddress)) {
        emit NodesUpdated(nodes, nodesAddress);
        nodes = nodesAddress;
    }

    function setStatus(IStatus statusAddress) external override restricted onlyNonZeroAddress(address(statusAddress)) {
        emit StatusUpdated(status, statusAddress);
        status = statusAddress;
        _pool.status = statusAddress;
    }

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

    function setVersion(string calldata newVersion) external override restricted {
        emit VersionUpdated(version, newVersion);
        version = newVersion;
    }

    function processSuccessfulDkg(DkgId round) external onlyDkg override {
        Committee storage committee = _getCommittee(lastCommitteeIndex);
        if (committee.dkg == round) {
            committee.commonPublicKey = dkg.getPublicKey(round);
            committee.startingTimestamp = Timestamp.wrap(block.timestamp + Duration.unwrap(transitionDelay));
            emit CommitteeDkgCompleted(lastCommitteeIndex, round, committee.startingTimestamp);
        }
    }

    function setCommitteeSize(uint256 size) external override restricted {
        emit CommitteeSizeUpdated(committeeSize, size);
        committeeSize = size;
    }

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

    function nodeRemoved(NodeId node) external override restricted {
        _setIneligible(node);
    }

    function nodeWhitelisted(NodeId node) external override restricted {
        if (staking.getNodeTotalStake(node) > FundLibrary.ZERO_FAIR && status.isHealthy(node)) {
            _setEligible(node);
        }
    }

    function nodeBlacklisted(NodeId node) external override restricted {
        _setIneligible(node);
    }

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

    function updateWeight(NodeId node, uint256 share) external override restricted {
        _updateWeight(node, share, status.isWhitelisted(node));
    }

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

    function ejectUnhealthyNode() public override {
        if (_pool.length() == 0) {
            return;
        }
        NodeId oldest = _pool.getOldestIsh();
        if (!status.isHealthy(oldest)) {
            _setIneligible(oldest);
        }
    }

    function getActiveCommitteeIndex() public view override returns (CommitteeIndex committeeIndex) {
        committeeIndex = lastCommitteeIndex;
        while (Timestamp.wrap(block.timestamp) < _getCommittee(committeeIndex).startingTimestamp) {
            committeeIndex = _previous(committeeIndex);
        }
    }

    // Private

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

    function _createSuccessorCommittee(NodeId[] memory nodes_)
        private
        returns (Committee storage committee)
    {
        return _createCommittee(nodes_, _next(getActiveCommitteeIndex()));
    }

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

    function _setEligible(NodeId node) private {
        _pool.add(node);
        emit NodeBecomesEligible(node);
        if (!staking.isNodeEnabled(node)) {
            staking.enable(node);
        }
    }

    function _setIneligible(NodeId node) private {
        if (_pool.remove(node)) {
            emit NodeLosesEligibility(node);
        }
        if (staking.isNodeEnabled(node)) {
            staking.disable(node);
        }
    }

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

    function _isEligible(NodeId node) private view returns (bool eligible) {
        return _pool.contains(node);
    }

    function _getCommittee(CommitteeIndex index) private view returns (Committee storage committee) {
        return committees[index];
    }

    function _committeeExists(CommitteeIndex index) private view returns (bool exists) {
        // false-positive: No real improvement in gas from replacing non-strict inequality
        // solhint-disable-next-line gas-strict-inequalities
        return CommitteeIndex.unwrap(lastCommitteeIndex) >= CommitteeIndex.unwrap(index);
    }

    function _safeGetRandom() private view returns (uint256 randomNumber) {
        if (skaleRng == address(0)) {
            return block.prevrandao;
        }
        return Precompiled.getRandomNumber(skaleRng);
    }

    function _canSelectNewCommittee() private view returns (bool canSelect) {
        Committee memory latestCommittee = _getCommittee(lastCommitteeIndex);
        return Timestamp.unwrap(latestCommittee.startingTimestamp) == type(uint256).max ||
            latestCommittee.startingTimestamp < Timestamp.wrap(block.timestamp);
    }

    function _next(CommitteeIndex index) private pure returns (CommitteeIndex nextIndex) {
        return CommitteeIndex.wrap(CommitteeIndex.unwrap(index) + 1);
    }

    function _previous(CommitteeIndex index) private pure returns (CommitteeIndex nextIndex) {
        return CommitteeIndex.wrap(CommitteeIndex.unwrap(index) - 1);
    }

    function _shareToWeight(uint256 share) private pure returns (uint256 weight)
    {
        return share;
    }

}

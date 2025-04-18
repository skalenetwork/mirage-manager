// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   Committee.sol - mirage-manager
 *   Copyright (C) 2025-Present SKALE Labs
 *   @author Dmytro Stebaiev
 *
 *   mirage-manager is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as published
 *   by the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   mirage-manager is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with mirage-manager.  If not, see <https://www.gnu.org/licenses/>.
 */

pragma solidity ^0.8.24;

import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {
    CommitteeIndex,
    ICommittee,
    Timestamp
} from "@skalenetwork/professional-interfaces/ICommittee.sol";
import { DkgId, IDkg } from "@skalenetwork/professional-interfaces/IDkg.sol";
import { INodes, NodeId } from "@skalenetwork/professional-interfaces/INodes.sol";
import { IStaking } from "@skalenetwork/professional-interfaces/IStaking.sol";
import { Duration, IStatus } from "@skalenetwork/professional-interfaces/IStatus.sol";


import { G2Operations } from "./dkg/fieldOperations/G2Operations.sol";
import { IRandom, Random } from "./Random.sol";
import { TypedSet } from "./structs/typed/TypedSet.sol";

contract Committee is AccessManagedUpgradeable, ICommittee {
    using Random for IRandom.RandomGenerator;
    using TypedSet for TypedSet.NodeIdSet;

    struct CommitteeAuxiliary {
        TypedSet.NodeIdSet nodes;
    }

    mapping (CommitteeIndex index => Committee committee) public committees;
    mapping (CommitteeIndex index => CommitteeAuxiliary committee) private _committeesAuxiliary;
    CommitteeIndex public lastCommitteeIndex;
    uint256 public committeeSize;
    Duration public transitionDelay;

    IDkg public dkg;
    INodes public nodes;
    IStatus public status;
    IStaking public staking;

    string public version;

    error TooFewCandidates(
        uint256 needed,
        uint256 available
    );
    error SenderIsNotDkg(
        address sender
    );
    error CommitteeNotFound(
        CommitteeIndex index
    );

    modifier onlyDkg() {
        require(msg.sender == address(dkg), SenderIsNotDkg(msg.sender));
        _;
    }

    function initialize(
        address initialAuthority,
        INodes nodesAddress,
        IDkg.G2Point memory commonPublicKey
    )
        public
        initializer
        override
    {
        __AccessManaged_init(initialAuthority);
        committeeSize = 22;
        transitionDelay = Duration.wrap(1 days);
        nodes = nodesAddress;

        _initializeGroup(commonPublicKey);
    }

    function select() external override restricted {
        (NodeId[] memory candidates, uint256 length) = _getEligibleNodes();
        _buildRandomSubset(candidates, length, committeeSize);
        Committee storage committee = _createSuccessorCommittee(candidates);
        committee.dkg = dkg.generate(committee.nodes);
    }

    function setDkg(IDkg dkgAddress) external override restricted {
        dkg = dkgAddress;
    }

    function setNodes(INodes nodesAddress) external override restricted {
        nodes = nodesAddress;
    }

    function setStatus(IStatus statusAddress) external override restricted {
        status = statusAddress;
    }

    function setStaking(IStaking stakingAddress) external override restricted {
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
        }
    }

    function setCommitteeSize(uint256 size) external override restricted {
        committeeSize = size;
    }

    function setTransitionDelay(Duration delay) external override restricted {
        transitionDelay = delay;
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

    function newNodeCreated(NodeId) external pure override {
        assert(true);
    }

    // Public

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

    function _initializeGroup(
        IDkg.G2Point memory commonPublicKey
    ) private {
        NodeId[] memory nodeIds = nodes.getActiveNodesIds();
        committeeSize = nodeIds.length;
        Committee storage initialCommittee =
            _createCommittee(nodeIds, CommitteeIndex.wrap(0));
        initialCommittee.commonPublicKey = commonPublicKey;
        initialCommittee.startingTimestamp = Timestamp.wrap(block.timestamp);
    }
    // TODO: improve algorithm _getEligibleNodes
    //slither-disable-start calls-loop
    function _isEligible(NodeId node) private view returns (bool eligible) {
        // slither-disable-next-line calls-loop
        return status.isHealthy(node) && status.isWhitelisted(node);
    }
    //slither-disable-end calls-loop


    function _getEligibleNodes() private view returns (NodeId[] memory candidates, uint256 length) {
        candidates = nodes.getActiveNodesIds();
        length = candidates.length;

        for (uint256 i = 0; i < length; ++i) {
            while ( i < length && !_isEligible(candidates[i])) {
                candidates[i] = candidates[length - 1];
                --length;
            }
        }
    }

    function _getCommittee(CommitteeIndex index) private view returns (Committee storage committee) {
        return committees[index];
    }

    function _buildRandomSubset(
        NodeId[] memory candidates,
        uint256 length,
        uint256 subsetSize
    )
        private
        view
    {
        require (!(length < subsetSize), TooFewCandidates(subsetSize, length));
        IRandom.RandomGenerator memory generator = Random.create(uint256(blockhash(block.number - 1)));
        for (uint256 i = 0; i < subsetSize; ++i) {
            uint256 index = generator.random(i, length);
            if (index > i) {
                (candidates[i], candidates[index]) = (candidates[index], candidates[i]);
            }
        }
    }

    function _committeeExists(CommitteeIndex index) private view returns (bool exists) {
        return !(CommitteeIndex.unwrap(lastCommitteeIndex) < CommitteeIndex.unwrap(index));
    }

    function _next(CommitteeIndex index) private pure returns (CommitteeIndex nextIndex) {
        return CommitteeIndex.wrap(CommitteeIndex.unwrap(index) + 1);
    }

    function _previous(CommitteeIndex index) private pure returns (CommitteeIndex nextIndex) {
        return CommitteeIndex.wrap(CommitteeIndex.unwrap(index) - 1);
    }
}

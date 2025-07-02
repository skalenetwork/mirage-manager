// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   DKG.sol - mirage-manager
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

// cspell:words Initializable

pragma solidity ^0.8.24;

import { AccessManagedUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { ICommittee } from "@skalenetwork/professional-interfaces/ICommittee.sol";
import { DkgId, IDkg } from "@skalenetwork/professional-interfaces/IDkg.sol";
import { INodes, NodeId } from "@skalenetwork/professional-interfaces/INodes.sol";

import { G2Operations } from "./utils/fieldOperations/G2Operations.sol";

contract DKG is AccessManagedUpgradeable, IDkg {
    using G2Operations for G2Point;

    enum Status {
        SUCCESS,
        BROADCAST,
        ALRIGHT,
        FAILED
    }

    struct Round {
        DkgId id;
        Status status;
        NodeId[] nodes;
        G2Point publicKey;
        uint256 numberOfBroadcasted;
        bytes32[] hashedData;
        uint256 numberOfCompleted;
        bool[] completed;
    }

    INodes public nodes;
    ICommittee public committee;

    mapping(DkgId dkg => Round round) public rounds;

    DkgId public lastDkgId;

    event BroadcastAndKeyShare(
        DkgId dkg,
        NodeId indexed node,
        G2Point[] verificationVector,
        KeyShare[] secretKeyContribution
    );

    event AllDataReceived(DkgId dkg, NodeId indexed node, uint256 nodeIndex);

    event SuccessfulDkg(DkgId dkg);

    error DkgIsNotSuccessful(DkgId id);
    error DkgIsNotInBroadcastStage(DkgId id);
    error DkgIsNotInAlrightStage(DkgId id);
    error IncorrectVerificationsVectorQuantity(uint256 actual, uint256 expected);
    error IncorrectSecretKeyContributionQuantity(uint256 actual, uint256 expected);
    error NodeDoesNotParticipateInDkg(NodeId node);
    error NodeAlreadyBroadcasted(NodeId node);
    error IncorrectG2Point(G2Point value);
    error NodeIsAlreadyAlright(NodeId node);

    modifier onlyBroadcastingDkg(DkgId dkg) {
        require(rounds[dkg].status == Status.BROADCAST, DkgIsNotInBroadcastStage(dkg));
        _;
    }

    modifier onlyAlrightDkg(DkgId dkg) {
        require(rounds[dkg].status == Status.ALRIGHT, DkgIsNotInAlrightStage(dkg));
        _;
    }

    function initialize(
        address initialAuthority,
        ICommittee committeeAddress,
        INodes nodesAddress
    )
        external
        override
        initializer
    {
        __AccessManaged_init(initialAuthority);
        committee = committeeAddress;
        nodes = nodesAddress;
    }

    function alright(DkgId dkg) external override onlyAlrightDkg(dkg) {
        uint256 n = rounds[dkg].nodes.length;
        NodeId node = nodes.getNodeId(msg.sender);
        uint256 index = _getIndex(dkg, node);
        Round storage round = rounds[dkg];
        require(!round.completed[index], NodeIsAlreadyAlright(node));
        round.completed[index] = true;
        ++round.numberOfCompleted;
        emit AllDataReceived(dkg, node, index);
        if (round.numberOfCompleted == n) {
            _processSuccessfulDkg(dkg);
        }
    }

    function broadcast(
        DkgId dkg,
        G2Point[] calldata verificationVector,
        KeyShare[] calldata secretKeyContribution
    )
        external
        override
        onlyBroadcastingDkg(dkg)
    {
        uint256 n = rounds[dkg].nodes.length;
        uint256 t = _getT(n);
        require(
            verificationVector.length == t,
            IncorrectVerificationsVectorQuantity(verificationVector.length, t)
        );
        require(
            secretKeyContribution.length == n,
            IncorrectSecretKeyContributionQuantity(secretKeyContribution.length, n)
        );
        NodeId node = nodes.getNodeId(msg.sender);
        uint256 index = _getIndex(dkg, node);
        Round storage round = rounds[dkg];
        require(!_isNodeBroadcasted(dkg, index), NodeAlreadyBroadcasted(node));

        ++round.numberOfBroadcasted;
        if (round.numberOfBroadcasted == n) {
            round.status = Status.ALRIGHT;
        }
        round.hashedData[index] = _hashData(secretKeyContribution, verificationVector);
        _contributeToPublicKey(round, verificationVector[0]);

        emit BroadcastAndKeyShare(dkg, node, verificationVector, secretKeyContribution);
    }

    function generate(NodeId[] calldata participants) external override returns (DkgId dkg) {
        return _createRound(participants);
    }

    function isNodeBroadcasted(
        DkgId dkg,
        NodeId node
    )
        external
        view
        override
        returns (bool broadcasted)
    {
        uint256 index = _getIndex(dkg, node);
        return _isNodeBroadcasted(dkg, index);
    }

    function getParticipants(DkgId dkg)
        external
        view
        override
        returns (NodeId[] memory participants)
    {
        return rounds[dkg].nodes;
    }

    function getPublicKey(DkgId dkg) external view override returns (G2Point memory publicKey) {
        require(rounds[dkg].status == Status.SUCCESS, DkgIsNotSuccessful(dkg));
        return rounds[dkg].publicKey;
    }

    // Private

    function _processSuccessfulDkg(DkgId dkg) private {
        rounds[dkg].status = Status.SUCCESS;
        emit SuccessfulDkg(dkg);
        committee.processSuccessfulDkg(dkg);
    }

    function _createRound(NodeId[] calldata participants) private returns (DkgId id) {
        lastDkgId = DkgId.wrap(DkgId.unwrap(lastDkgId) + 1);
        id = lastDkgId;
        rounds[id] = Round({
            id: id,
            status: Status.BROADCAST,
            nodes: participants,
            publicKey: G2Operations.getG2Zero(),
            numberOfBroadcasted: 0,
            hashedData: new bytes32[](participants.length),
            numberOfCompleted: 0,
            completed: new bool[](participants.length)
        });
    }

    function _contributeToPublicKey(Round storage round, G2Point memory value) private {
        require(value.isG2(), IncorrectG2Point(value));
        round.publicKey = value.addG2(round.publicKey);
    }

    function _getIndex(DkgId dkg, NodeId node) private view returns (uint256 index) {
        uint256 length = rounds[dkg].nodes.length;
        for (index = 0; index < length; ++index) {
            if (rounds[dkg].nodes[index] == node) {
                return index;
            }
        }
        revert NodeDoesNotParticipateInDkg(node);
    }

    function _isNodeBroadcasted(DkgId dkg, uint256 index) private view returns (bool broadcasted) {
        return rounds[dkg].hashedData[index] != bytes32(0);
    }

    function _getT(uint256 n) private pure returns (uint256 t) {
        return (n * 2 + 1) / 3;
    }

    function _hashData(
        KeyShare[] calldata secretKeyContribution,
        G2Point[] calldata verificationVector
    )
        private
        pure
        returns (bytes32 hash)
    {
        return keccak256(abi.encode(secretKeyContribution, verificationVector));
    }
}

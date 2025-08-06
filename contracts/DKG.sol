// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   DKG.sol - fair-manager
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

// cspell:words Initializable

pragma solidity ^0.8.24;

import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {ICommittee} from "@skalenetwork/fair-manager-interfaces/ICommittee.sol";
import {DkgId, IDkg} from "@skalenetwork/fair-manager-interfaces/IDkg.sol";
import {INodes, NodeId} from "@skalenetwork/fair-manager-interfaces/INodes.sol";

import {TypedMap} from "./structs/typed/TypedMap.sol";
import {TypedSet} from "./structs/typed/TypedSet.sol";
import {G2Operations} from "./utils/fieldOperations/G2Operations.sol";


contract DKG is AccessManagedUpgradeable, IDkg {
    using G2Operations for G2Point;
    using TypedMap for TypedMap.NodeIdToBytes32Map;
    using TypedSet for TypedSet.NodeIdSet;

    struct RoundData {
        DkgId id;
        Status status;
        TypedSet.NodeIdSet nodes;
        G2Point publicKey;
        uint256 startingBlockNumber;
        TypedMap.NodeIdToBytes32Map hashedData;
        TypedSet.NodeIdSet completed;
    }

    INodes public nodes;
    ICommittee public committee;

    mapping(DkgId dkg => RoundData round) private _rounds;

    DkgId public lastDkgId;

    event BroadcastAndKeyShare(
        DkgId dkg,
        NodeId indexed node,
        G2Point[] verificationVector,
        KeyShare[] secretKeyContribution
    );

    event AllDataReceived(
        DkgId dkg,
        NodeId indexed node
    );

    event SuccessfulDkg(
        DkgId dkg
    );

    error DkgIsNotSuccessful(DkgId id);
    error DkgIsNotInBroadcastStage(DkgId id);
    error DkgIsNotInAlrightStage(DkgId id);
    error IncorrectVerificationsVectorQuantity(
        uint256 actual,
        uint256 expected
    );
    error IncorrectSecretKeyContributionQuantity(
        uint256 actual,
        uint256 expected
    );
    error DuplicatedNodeId(NodeId node);
    error NodeDoesNotParticipateInDkg(NodeId node);
    error NodeAlreadyBroadcasted(NodeId node);
    error IncorrectG2Point(G2Point value);
    error NodeIsAlreadyAlright(NodeId node);
    error RoundDoesNotExist(DkgId dkg);

    modifier onlyBroadcastingDkg(DkgId dkg) {
        // the modifier checks that the DKG is only in BROADCAST stage
        // disable the warning because of false positive
        // slither-disable-next-line incorrect-equality
        require(_rounds[dkg].status == Status.BROADCAST, DkgIsNotInBroadcastStage(dkg));
        _;
    }

    modifier onlyAlrightDkg(DkgId dkg) {
        // the modifier checks that the DKG is only in ALRIGHT stage
        // disable the warning because of false positive
        // slither-disable-next-line incorrect-equality
        require(_rounds[dkg].status == Status.ALRIGHT, DkgIsNotInAlrightStage(dkg));
        _;
    }

    function initialize(
        address initialAuthority,
        ICommittee committeeAddress,
        INodes nodesAddress
    )
        public
        override
        initializer
    {
        __AccessManaged_init(initialAuthority);
        committee = committeeAddress;
        nodes = nodesAddress;
    }

    function alright(DkgId dkg) external override onlyAlrightDkg(dkg) {
        uint256 n = _rounds[dkg].nodes.length();
        NodeId node = nodes.getNodeId(msg.sender);
        RoundData storage round = _rounds[dkg];
        require(round.nodes.contains(node), NodeDoesNotParticipateInDkg(node));
        require(round.completed.add(node), NodeIsAlreadyAlright(node));
        emit AllDataReceived(dkg, node);
        if (round.completed.length() + 1 > n) {
            _processSuccessfulDkg(dkg);
        }
    }

    function broadcast(
        DkgId dkg,
        G2Point[] calldata verificationVector,
        KeyShare[] calldata secretKeyContribution
    ) external onlyBroadcastingDkg(dkg) override {
        uint256 n = _rounds[dkg].nodes.length();
        uint256 t = _getT(n);
        // the verificationVector length should be strictly be equal t
        // disable the warning because of false positive
        // slither-disable-next-line incorrect-equality
        require(verificationVector.length == t, IncorrectVerificationsVectorQuantity(verificationVector.length, t));
        // the secretKeyContribution length should be strictly be equal n
        // disable the warning because of false positive
        // slither-disable-next-line incorrect-equality
        require(
            secretKeyContribution.length == n,
            IncorrectSecretKeyContributionQuantity(secretKeyContribution.length, n)
        );
        NodeId node = nodes.getNodeId(msg.sender);
        RoundData storage round = _rounds[dkg];
        require(round.nodes.contains(node), NodeDoesNotParticipateInDkg(node));
        require(
            round.hashedData.set(node, _hashData(secretKeyContribution, verificationVector)),
            NodeAlreadyBroadcasted(node)
        );

        if ( round.hashedData.length() + 1 > n ) {
            round.status = Status.ALRIGHT;
        }

        _contributeToPublicKey(round, verificationVector[0]);

        emit BroadcastAndKeyShare(
            dkg,
            node,
            verificationVector,
            secretKeyContribution
        );
    }

    function generate(NodeId[] calldata participants) external override returns (DkgId dkg) {
        return _createRound(participants);
    }

    function isNodeBroadcasted(DkgId dkg, NodeId node) external view override returns (bool broadcasted) {
        return _rounds[dkg].hashedData.contains(node);
    }

    function getParticipants(DkgId dkg) external view override returns (NodeId[] memory participants) {
        return _rounds[dkg].nodes.values();
    }

    function getPublicKey(DkgId dkg) external view override returns (G2Point memory publicKey) {
        // the should return the public key only if the DKG is successful
        // disable the warning because of false positive
        // slither-disable-next-line incorrect-equality
        require(_rounds[dkg].status == Status.SUCCESS, DkgIsNotSuccessful(dkg));
        return _rounds[dkg].publicKey;
    }

    function getRound(DkgId dkg) external view override returns (Round memory round) {
        require(dkg != DkgId.wrap(0), RoundDoesNotExist(dkg));
        require(_rounds[dkg].id == dkg, RoundDoesNotExist(dkg));
        uint256 n = _rounds[dkg].nodes.length();

        bytes32[] memory orderedHashedData = new bytes32[](n);
        bool[] memory orderedCompleted = new bool[](n);
        for (uint256 i = 0; i < n; ++i) {
            NodeId node = _rounds[dkg].nodes.at(i);
            (bool broadcasted, bytes32 hash) = _rounds[dkg].hashedData.tryGet(node);
            if (broadcasted) {
                orderedHashedData[i] = hash;
            }
            orderedCompleted[i] = _rounds[dkg].completed.contains(node);
        }

        return Round({
            id: _rounds[dkg].id,
            status: _rounds[dkg].status,
            nodes: _rounds[dkg].nodes.values(),
            publicKey: _rounds[dkg].publicKey,
            startingBlockNumber: _rounds[dkg].startingBlockNumber,
            numberOfBroadcasted: _rounds[dkg].hashedData.length(),
            hashedData: orderedHashedData,
            numberOfCompleted: _rounds[dkg].completed.length(),
            completed: orderedCompleted
        });
    }

    // Private

    function _processSuccessfulDkg(DkgId dkg) private {
        _rounds[dkg].status = Status.SUCCESS;
        emit SuccessfulDkg(dkg);
        committee.processSuccessfulDkg(dkg);
    }

    function _createRound(NodeId[] calldata participants) private returns (DkgId id) {
        uint256 n = participants.length;
        lastDkgId = DkgId.wrap(DkgId.unwrap(lastDkgId) + 1);
        id = lastDkgId;
        _rounds[id].id = id;
        for (uint256 i = 0; i < n; ++i) {
            require(_rounds[id].nodes.add(participants[i]), DuplicatedNodeId(participants[i]));
        }
        _rounds[id].status = Status.BROADCAST;
        _rounds[id].hashedData.clear();
        _rounds[id].completed.clear();
        _rounds[id].publicKey = G2Operations.getG2Zero();
        _rounds[id].startingBlockNumber = block.number;
    }

    function _contributeToPublicKey(RoundData storage round, G2Point memory value) private {
        require(value.isG2(), IncorrectG2Point(value));
        round.publicKey = value.addG2(round.publicKey);
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

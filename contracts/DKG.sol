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

import { AccessManagedUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { ICommittee } from "@skalenetwork/fair-manager-interfaces/ICommittee.sol";
import { DkgId, IDkg } from "@skalenetwork/fair-manager-interfaces/IDkg.sol";
import { INodes, NodeId } from "@skalenetwork/fair-manager-interfaces/INodes.sol";

import { TypedMap } from "./structs/typed/TypedMap.sol";
import { TypedSet } from "./structs/typed/TypedSet.sol";
import { G2Operations } from "./utils/fieldOperations/G2Operations.sol";

/**
 * @title DKG
 * @notice Handles the Distributed Key Generation process for the committees.
 */
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

    /// @notice The Nodes contract instance.
    INodes public nodes;
    /// @notice The Committee contract instance.
    ICommittee public committee;

    mapping(DkgId dkg => RoundData round) private _rounds;

    /// @notice The ID of the last DKG round.
    DkgId public lastDkgId;

    /**
     * @notice Emitted when a node broadcasts its key share and verification vector.
     * @param dkg The ID of the DKG round.
     * @param node The ID of the node.
     * @param verificationVector The node's verification vector.
     * @param secretKeyContribution The node's secret key contribution.
     */
    event BroadcastAndKeyShare(
        DkgId dkg, NodeId indexed node, G2Point[] verificationVector, KeyShare[] secretKeyContribution
    );

    /**
     * @notice Emitted when all data has been received from a node.
     * @param dkg The ID of the DKG round.
     * @param node The ID of the node.
     */
    event AllDataReceived(DkgId dkg, NodeId indexed node);

    /**
     * @notice Emitted when a DKG round is successful.
     * @param dkg The ID of the DKG round.
     */
    event SuccessfulDkg(DkgId dkg);

    /**
     * @notice Emitted when a new DKG round is created.
     * @param dkgId The ID of the newly created DKG round.
     * @param participants The array of node IDs participating in the DKG.
     * @param startingBlockNumber The block number when the DKG round was created.
     */
    event DkgRoundCreated(DkgId indexed dkgId, NodeId[] participants, uint256 startingBlockNumber);

    error DkgIsNotSuccessful(DkgId id);
    error DkgIsNotInBroadcastStage(DkgId id);
    error DkgIsNotInAlrightStage(DkgId id);
    error IncorrectVerificationsVectorQuantity(uint256 actual, uint256 expected);
    error IncorrectSecretKeyContributionQuantity(uint256 actual, uint256 expected);
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

    /**
     * @notice Initializes the DKG contract.
     * @param initialAuthority The address of the initial authority.
     * @param committeeAddress The address of the Committee contract.
     * @param nodesAddress The address of the Nodes contract.
     */
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

    /**
     * @notice Signals that a node is ready to proceed to the next phase of the DKG.
     * @param dkg The ID of the DKG round.
     */
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

    /**
     * @notice Broadcasts a node's verification vector and secret key contribution.
     * @param dkg The ID of the DKG round.
     * @param verificationVector The node's verification vector.
     * @param secretKeyContribution The node's secret key contribution.
     */
    function broadcast(
        DkgId dkg,
        G2Point[] calldata verificationVector,
        KeyShare[] calldata secretKeyContribution
    )
        external
        override
        onlyBroadcastingDkg(dkg)
    {
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
            secretKeyContribution.length == n, IncorrectSecretKeyContributionQuantity(secretKeyContribution.length, n)
        );
        NodeId node = nodes.getNodeId(msg.sender);
        RoundData storage round = _rounds[dkg];
        require(round.nodes.contains(node), NodeDoesNotParticipateInDkg(node));
        require(
            round.hashedData.set(node, _hashData(secretKeyContribution, verificationVector)),
            NodeAlreadyBroadcasted(node)
        );

        if (round.hashedData.length() + 1 > n) {
            round.status = Status.ALRIGHT;
        }

        _contributeToPublicKey(round, verificationVector[0]);

        emit BroadcastAndKeyShare(dkg, node, verificationVector, secretKeyContribution);
    }

    /**
     * @notice Generates a new DKG round with the given participants.
     * @param participants The array of node IDs participating in the DKG.
     * @return dkg The ID of the newly generated DKG round.
     */
    function generate(NodeId[] calldata participants) external override restricted returns (DkgId dkg) {
        return _createRound(participants);
    }

    /**
     * @notice Checks if a node has broadcasted its data in a specific DKG round.
     * @param dkg The ID of the DKG round.
     * @param node The ID of the node.
     * @return broadcasted True if the node has broadcasted, false otherwise.
     */
    function isNodeBroadcasted(DkgId dkg, NodeId node) external view override returns (bool broadcasted) {
        return _rounds[dkg].hashedData.contains(node);
    }

    /**
     * @notice Retrieves the participants of a specific DKG round.
     * @param dkg The ID of the DKG round.
     * @return participants An array of node IDs participating in the DKG.
     */
    function getParticipants(DkgId dkg) external view override returns (NodeId[] memory participants) {
        return _rounds[dkg].nodes.values();
    }

    /**
     * @notice Retrieves the public key of a successful DKG round.
     * @param dkg The ID of the DKG round.
     * @return publicKey The public key of the DKG round.
     */
    function getPublicKey(DkgId dkg) external view override returns (G2Point memory publicKey) {
        require(dkg != DkgId.wrap(0), RoundDoesNotExist(dkg));
        require(_rounds[dkg].id == dkg, RoundDoesNotExist(dkg));
        // the should return the public key only if the DKG is successful
        // disable the warning because of false positive
        // slither-disable-next-line incorrect-equality
        require(_rounds[dkg].status == Status.SUCCESS, DkgIsNotSuccessful(dkg));
        return _rounds[dkg].publicKey;
    }

    /**
     * @notice Retrieves the details of a specific DKG round.
     * @param dkg The ID of the DKG round.
     * @return round The details of the DKG round.
     */
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

    /**
     * @notice Processes a successful DKG round.
     * @param dkg The ID of the DKG round.
     */
    function _processSuccessfulDkg(DkgId dkg) private {
        _rounds[dkg].status = Status.SUCCESS;
        emit SuccessfulDkg(dkg);
        committee.processSuccessfulDkg(dkg);
    }

    /**
     * @notice Creates a new DKG round.
     * @param participants The array of node IDs participating in the DKG.
     * @return id The ID of the newly created DKG round.
     */
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
        emit DkgRoundCreated(id, participants, block.number);
    }

    /**
     * @notice Contributes to the public key of a DKG round.
     * @param round The DKG round data.
     * @param value The G2 point to contribute.
     */
    function _contributeToPublicKey(RoundData storage round, G2Point memory value) private {
        require(value.isG2(), IncorrectG2Point(value));
        round.publicKey = value.addG2(round.publicKey);
    }

    /**
     * @notice Calculates the threshold `t` for a given number of participants `n`.
     * @param n The number of participants.
     * @return t The threshold value.
     */
    function _getT(uint256 n) private pure returns (uint256 t) {
        return (n * 2 + 1) / 3;
    }

    /**
     * @notice Hashes the secret key contribution and verification vector.
     * @param secretKeyContribution The secret key contribution.
     * @param verificationVector The verification vector.
     * @return hash The hash of the data.
     */
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

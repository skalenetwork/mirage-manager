// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   DKG.sol - fair-manager
 *   Copyright (C) 2025-Present SKALE Labs
 *   @author Dmytro Stebaiev
 *   @author Eduardo Vasques
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
import { InvalidCommitteeAddress, InvalidNodesAddress } from "./utils/errors.sol";
import {G2Operations} from "./utils/fieldOperations/G2Operations.sol";

/**
 * @title DKG
 * @author Dmytro Stebaiev
 * @author Eduardo Vasques
 *
 * @notice Manages Distributed Key Generation (DKG) rounds for committee formation
 * @dev Implements the DKG protocol with BROADCAST and ALRIGHT stages to generate
 * shared public keys. Participants broadcast verification vectors and secret key
 * contributions, then confirm receipt of all required data before the DKG is marked successful.
 */
contract DKG is AccessManagedUpgradeable, IDkg {
    using G2Operations for G2Point;
    using TypedMap for TypedMap.NodeIdToBytes32Map;
    using TypedSet for TypedSet.NodeIdSet;

    /// @dev Internal data structure for tracking DKG round state
    struct RoundData {
        DkgId id;
        Status status;
        TypedSet.NodeIdSet nodes;
        G2Point publicKey;
        uint256 startingBlockNumber;
        TypedMap.NodeIdToBytes32Map hashedData;
        TypedSet.NodeIdSet completed;
    }

    /// @notice Reference to the Nodes contract
    INodes public nodes;

    /// @notice Reference to the Committee contract
    ICommittee public committee;

    /// @dev Mapping from DKG ID to round data
    mapping(DkgId dkg => RoundData round) private _rounds;

    /// @notice The ID of the most recently created DKG round
    DkgId public lastDkgId;

    /**
     * @notice Emitted when a node broadcasts its verification vector and key shares
     * @param dkg The DKG round ID
     * @param node The node that broadcast the data
     * @param verificationVector The verification vector
     * @param secretKeyContribution The encrypted secret key shares for other nodes
     */
    event BroadcastAndKeyShare(
        DkgId dkg,
        NodeId indexed node,
        G2Point[] verificationVector,
        KeyShare[] secretKeyContribution
    );

    /**
     * @notice Emitted when a node confirms receipt of all required DKG data
     * @param dkg The DKG round ID
     * @param node The node that confirmed all data received
     */
    event AllDataReceived(
        DkgId dkg,
        NodeId indexed node
    );

    /**
     * @notice Emitted when a DKG round completes successfully
     * @param dkg The DKG round ID that succeeded
     */
    event SuccessfulDkg(
        DkgId dkg
    );

    /**
     * @notice Emitted when a new DKG round is created
     * @param dkgId The new DKG round ID
     * @param participants The array of nodes participating in this round
     * @param startingBlockNumber The block number when the round started
     */
    event DkgRoundCreated(DkgId indexed dkgId, NodeId[] participants, uint256 startingBlockNumber);

    /**
     * @notice DKG round did not complete successfully
     * @param id The DKG round ID that failed
     */
    error DkgIsNotSuccessful(DkgId id);

    /**
     * @notice Operation requires DKG to be in BROADCAST stage
     * @param id The DKG round ID
     */
    error DkgIsNotInBroadcastStage(DkgId id);

    /**
     * @notice Operation requires DKG to be in ALRIGHT stage
     * @param id The DKG round ID
     */
    error DkgIsNotInAlrightStage(DkgId id);

    /**
     * @notice Incorrect number of verification vector elements
     * @param actual The actual number of elements provided
     * @param expected The expected number of elements (threshold t)
     */
    error IncorrectVerificationsVectorQuantity(
        uint256 actual,
        uint256 expected
    );

    /**
     * @notice Incorrect number of secret key contribution shares
     * @param actual The actual number of shares provided
     * @param expected The expected number of shares (n participants)
     */
    error IncorrectSecretKeyContributionQuantity(
        uint256 actual,
        uint256 expected
    );

    /**
     * @notice A node ID appears more than once in the participant list
     * @param node The duplicated node ID
     */
    error DuplicatedNodeId(NodeId node);

    /**
     * @notice Node is not a participant in this DKG round
     * @param node The node ID that is not participating
     */
    error NodeDoesNotParticipateInDkg(NodeId node);

    /**
     * @notice Node has already broadcast its data for this round
     * @param node The node ID that already broadcast
     */
    error NodeAlreadyBroadcasted(NodeId node);

    /**
     * @notice The provided G2 point is not valid
     * @param value The invalid G2 point
     */
    error IncorrectG2Point(G2Point value);

    /**
     * @notice G2 zero point is not allowed
     * @param value The G2 point provided
     */
    error G2ZeroPointNotAllowed(G2Point value);

    /**
     * @notice Node has already confirmed all data received
     * @param node The node ID that already confirmed
     */
    error NodeIsAlreadyAlright(NodeId node);

    /**
     * @notice The specified DKG round does not exist
     * @param dkg The non-existent DKG round ID
     */
    error RoundDoesNotExist(DkgId dkg);

    /// @dev Ensures DKG is in the BROADCAST stage
    modifier onlyBroadcastingDkg(DkgId dkg) {
        // the modifier checks that the DKG is only in BROADCAST stage
        // disable the warning because of false positive
        // slither-disable-next-line incorrect-equality
        require(_rounds[dkg].status == Status.BROADCAST, DkgIsNotInBroadcastStage(dkg));
        _;
    }

    /// @dev Ensures DKG is in the ALRIGHT stage
    modifier onlyAlrightDkg(DkgId dkg) {
        // the modifier checks that the DKG is only in ALRIGHT stage
        // disable the warning because of false positive
        // slither-disable-next-line incorrect-equality
        require(_rounds[dkg].status == Status.ALRIGHT, DkgIsNotInAlrightStage(dkg));
        _;
    }

    /**
     * @notice Initializes the DKG contract
     * @dev Sets up access control and references to Committee and Nodes contracts
     * @param initialAuthority The address of the access manager
     * @param committeeAddress The address of the Committee contract
     * @param nodesAddress The address of the Nodes contract
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
        require(address(committeeAddress) != address(0), InvalidCommitteeAddress());
        require(address(nodesAddress) != address(0), InvalidNodesAddress());
        __AccessManaged_init(initialAuthority);
        committee = committeeAddress;
        nodes = nodesAddress;
    }

    /**
     * @notice Confirms that a node has received all DKG data
     * @dev Only callable during ALRIGHT stage. When all nodes submit valid Alright, DKG succeeds.
     * @param dkg The DKG round ID
     */
    function alright(DkgId dkg) external override onlyAlrightDkg(dkg) {
        uint256 n = _rounds[dkg].nodes.length();
        NodeId node = nodes.getNodeId(msg.sender);
        RoundData storage round = _rounds[dkg];
        require(round.nodes.contains(node), NodeDoesNotParticipateInDkg(node));
        require(round.completed.add(node), NodeIsAlreadyAlright(node));
        emit AllDataReceived(dkg, node);
        // false-positive: No real improvement in gas from replacing non-strict inequality
        // solhint-disable-next-line gas-strict-inequalities
        if (round.completed.length() >= n) {
            _processSuccessfulDkg(dkg);
        }
    }

    /**
     * @notice Broadcasts verification vector and secret key contributions for DKG
     * @dev Only callable during BROADCAST stage. Validates vector and contribution sizes.
     * @dev When all nodes broadcast, advances to ALRIGHT stage.
     * @param dkg The DKG round ID
     * @param verificationVector The verification vector (length t) for the secret polynomial
     * @param secretKeyContribution The encrypted secret key shares (length n) for other nodes
     */
    function broadcast(
        DkgId dkg,
        G2Point[] calldata verificationVector,
        KeyShare[] calldata secretKeyContribution
    ) external onlyBroadcastingDkg(dkg) override {
        uint256 n = _rounds[dkg].nodes.length();
        uint256 t = _getT(n);
        // The verificationVector length should be strictly equal to t
        // disable the warning because of false positive
        // slither-disable-next-line incorrect-equality
        require(verificationVector.length == t, IncorrectVerificationsVectorQuantity(verificationVector.length, t));
        // The secretKeyContribution length should be strictly equal to n
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

        // false-positive: No real improvement in gas from replacing non-strict inequality
        // solhint-disable-next-line gas-strict-inequalities
        if ( round.hashedData.length() >= n ) {
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

    /**
     * @notice Generates a new DKG round with the specified participants
     * @dev Only callable by Committee contract (restricted). Creates a new round in BROADCAST stage.
     * @param participants The array of node IDs that will participate in this DKG round
     * @return dkg The ID of the newly created DKG round
     */
    function generate(NodeId[] calldata participants) external override restricted returns (DkgId dkg) {
        return _createRound(participants);
    }

    /**
     * @notice Checks if a node has broadcast its data for a DKG round
     * @dev Returns true if the node's hashed data is stored in the round
     * @param dkg The DKG round ID
     * @param node The node ID to check
     * @return broadcasted True if the node has broadcast, false otherwise
     */
    function isNodeBroadcasted(DkgId dkg, NodeId node) external view override returns (bool broadcasted) {
        return _rounds[dkg].hashedData.contains(node);
    }

    /**
     * @notice Gets the list of participants in a DKG round
     * @dev Returns all node IDs that were registered for this DKG round
     * @param dkg The DKG round ID
     * @return participants The array of participating node IDs
     */
    function getParticipants(DkgId dkg) external view override returns (NodeId[] memory participants) {
        return _rounds[dkg].nodes.values();
    }

    /**
     * @notice Gets the common public key generated by a successful DKG round
     * @dev Only returns the key if the DKG round completed successfully
     * @param dkg The DKG round ID
     * @return publicKey The common public key generated by the DKG
     */
    function getPublicKey(DkgId dkg) external view override returns (G2Point memory publicKey) {
        require(dkg != DkgId.wrap(0), RoundDoesNotExist(dkg));
        require(_rounds[dkg].id == dkg, RoundDoesNotExist(dkg));
        // Should return the public key only if the DKG is successful
        // disable the warning because of false positive
        // slither-disable-next-line incorrect-equality
        require(_rounds[dkg].status == Status.SUCCESS, DkgIsNotSuccessful(dkg));
        return _rounds[dkg].publicKey;
    }

    /**
     * @notice Gets comprehensive information about a DKG round
     * @dev Returns all round data including participant status and hashed broadcast data
     * @param dkg The DKG round ID
     * @return round The complete round information structure
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
     * @notice Marks a DKG round as successful and notifies the committee
     * @dev Updates round status to SUCCESS and calls committee to process the result
     * @param dkg The DKG round ID that succeeded
     */
    function _processSuccessfulDkg(DkgId dkg) private {
        _rounds[dkg].status = Status.SUCCESS;
        emit SuccessfulDkg(dkg);
        committee.processSuccessfulDkg(dkg);
    }

    /**
     * @notice Creates a new DKG round with the specified participants
     * @dev Initializes round data, validates no duplicate participants, sets BROADCAST status
     * @param participants The array of node IDs to participate in this round
     * @return id The newly created DKG round ID
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
     * @notice Adds a node's contribution to the common public key
     * @dev Validates the G2 point and aggregates it into the round's public key
     * @param round The round data structure to update
     * @param value The G2 point to add to the public key
     */
    function _contributeToPublicKey(RoundData storage round, G2Point memory value) private {
        require(value.isG2(), IncorrectG2Point(value));
        require(!value.isG2Zero(), G2ZeroPointNotAllowed(value));
        round.publicKey = value.addG2(round.publicKey);
    }

    /**
     * @notice Calculates the threshold t for a given number of participants
     * @dev Uses formula t = (n * 2 + 1) / 3 for Byzantine fault tolerance
     * @param n The number of participants
     * @return t The threshold value
     */
    function _getT(uint256 n) private pure returns (uint256 t) {
        return (n * 2 + 1) / 3;
    }

    /**
     * @notice Computes a hash of the secret key contribution and verification vector
     * @dev Uses keccak256 to create a commitment hash for broadcast data
     * @param secretKeyContribution The secret key shares for participants
     * @param verificationVector The verification vector for the secret
     * @return hash The keccak256 hash of the encoded data
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

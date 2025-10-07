// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   Status.sol - fair-manager
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
import { ICommittee } from "@skalenetwork/fair-manager-interfaces/ICommittee.sol";
import { INodes, NodeId } from "@skalenetwork/fair-manager-interfaces/INodes.sol";
import { Duration, IStatus } from "@skalenetwork/fair-manager-interfaces/IStatus.sol";

import { TypedSet } from "./structs/typed/TypedSet.sol";

/**
 * @title Status
 * @notice Tracks the status of nodes, including whitelisting and heartbeats.
 */
contract Status is AccessManagedUpgradeable, IStatus {

    using TypedSet for TypedSet.NodeIdSet;

    /// @notice The interval for heartbeats
    Duration public heartbeatInterval;
    /// @notice Mapping from node ID to the timestamp of its last heartbeat
    mapping(NodeId id => uint256 timestamp) public lastHeartbeatTimestamp;
    TypedSet.NodeIdSet private _whitelist;

    /// @notice The Committee contract interface
    ICommittee public committee;
    /// @notice The Nodes contract interface
    INodes public nodes;

    /**
     * @notice Emitted when the heartbeat interval is updated
     * @param oldInterval The old heartbeat interval.
     * @param newInterval The new heartbeat interval.
     */
    event HeartbeatIntervalUpdated(Duration oldInterval, Duration newInterval);
    /**
     * @notice Emitted when a node is whitelisted
     * @param nodeId The ID of the whitelisted node.
     */
    event NodeWhitelisted(NodeId indexed nodeId);
    /**
     * @notice Emitted when a node is removed from the whitelist
     * @param nodeId The ID of the node removed from the whitelist.
     */
    event NodeRemovedFromWhitelist(NodeId indexed nodeId);
    /**
     * @notice Emitted when a node's data is removed
     * @param nodeId The ID of the node whose data is removed.
     */
    event NodeDataRemoved(NodeId indexed nodeId);
    /**
     * @notice Emitted when a heartbeat is received from a node
     * @param nodeId The ID of the node.
     * @param timestamp The timestamp of the heartbeat.
     */
    event HeartbeatReceived(NodeId indexed nodeId, uint256 timestamp);

    error NodeAlreadyWhitelisted(NodeId nodeId);
    error NodeNotWhitelisted(NodeId nodeId);
    error NodeDoesNotExist(NodeId nodeId);

    /**
     * @notice Initializes the Status contract
     * @param initialAuthority The address of the initial authority
     * @param nodesAddress The address of the nodes contract
     * @param committeeAddress The address of the committee contract
     */
    function initialize(
        address initialAuthority,
        INodes nodesAddress,
        ICommittee committeeAddress
    )
        external
        override
        initializer
    {
        __AccessManaged_init(initialAuthority);
        nodes = nodesAddress;
        committee = committeeAddress;
        heartbeatInterval = Duration.wrap(5 minutes);
    }

    /**
     * @notice Allows node owners to submit heartbeats
     */
    function alive() external override {
        // Nodes.sol will revert if sender has no Active Node
        NodeId nodeId = nodes.getNodeId(msg.sender);

        lastHeartbeatTimestamp[nodeId] = block.timestamp;
        emit HeartbeatReceived(nodeId, block.timestamp);

        if (isWhitelisted(nodeId)) {
            committee.processHeartbeat(nodeId);
        }
    }

    /**
     * @notice Sets the heartbeat interval
     * @param interval The new heartbeat interval
     */
    function setHeartbeatInterval(Duration interval) external override restricted {
        Duration oldInterval = heartbeatInterval;
        heartbeatInterval = interval;
        emit HeartbeatIntervalUpdated(oldInterval, interval);
    }

    /**
     * @notice Whitelists a node
     * @param nodeId The ID of the node to whitelist
     */
    function whitelistNode(NodeId nodeId) external override restricted {
        bool isActive = nodes.activeNodeExists(nodeId);
        require(isActive || nodes.passiveNodeExists(nodeId), NodeDoesNotExist(nodeId));

        require(_whitelist.add(nodeId), NodeAlreadyWhitelisted(nodeId));
        emit NodeWhitelisted(nodeId);
        if (isActive) {
            committee.nodeWhitelisted(nodeId);
        }
    }

    /**
     * @notice Removes a node from the whitelist
     * @param nodeId The ID of the node to remove
     */
    function removeNodeFromWhitelist(NodeId nodeId) external override restricted {
        require(_whitelist.remove(nodeId), NodeNotWhitelisted(nodeId));
        bool isActive = nodes.activeNodeExists(nodeId);
        emit NodeRemovedFromWhitelist(nodeId);
        if (isActive) {
            committee.nodeBlacklisted(nodeId);
        }
    }

    /**
     * @notice Handles the removal of a node
     * @param nodeId The ID of the node to remove
     */
    function nodeRemoved(NodeId nodeId) external override restricted {
        if (_whitelist.contains(nodeId)) {
            assert(_whitelist.remove(nodeId));
        }
        delete lastHeartbeatTimestamp[nodeId];
        emit NodeDataRemoved(nodeId);
    }

    /**
     * @notice Gets the list of whitelisted nodes
     * @return nodeIds The list of whitelisted node IDs
     */
    function getWhitelistedNodes() external view override returns (NodeId[] memory nodeIds) {
        nodeIds = _whitelist.values();
    }

    /**
     * @notice Checks if a node is whitelisted
     * @param nodeId The ID of the node
     * @return whitelisted True if the node is whitelisted
     */
    function isWhitelisted(NodeId nodeId) public view override returns (bool whitelisted) {
        whitelisted = _whitelist.contains(nodeId);
    }

    /**
     * @notice Checks if a node is healthy
     * @param nodeId The ID of the node
     * @return healthy True if the node is healthy
     */
    function isHealthy(NodeId nodeId) public view override returns (bool healthy) {
        uint256 interval = block.timestamp - lastHeartbeatTimestamp[nodeId];
        healthy = interval < Duration.unwrap(heartbeatInterval);
    }

}

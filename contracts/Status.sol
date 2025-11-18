// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   Status.sol - fair-manager
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

pragma solidity ^0.8.24;

import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {ICommittee} from "@skalenetwork/fair-manager-interfaces/ICommittee.sol";
import {INodes, NodeId} from "@skalenetwork/fair-manager-interfaces/INodes.sol";
import {Duration, IStatus} from "@skalenetwork/fair-manager-interfaces/IStatus.sol";

import {TypedSet} from "./structs/typed/TypedSet.sol";
import {DEFAULT_HEARTBEAT_INTERVAL} from "./utils/constants.sol";
import {NodeDoesNotExist} from "./utils/errors.sol";

/**
 * @title Status
 * @author Dmytro Stebaiev
 * @author Eduardo Vasques
 *
 * @notice Manages node health monitoring and whitelisting in the FAIR network
 */
contract Status is AccessManagedUpgradeable, IStatus {
    using TypedSet for TypedSet.NodeIdSet;

    /// @notice Maximum allowed time between heartbeats before a node is considered unhealthy
    Duration public heartbeatInterval;

    /// @notice Mapping of node IDs to their last heartbeat timestamp
    mapping(NodeId id => uint256 timestamp) public lastHeartbeatTimestamp;

    /// @dev Internal set of whitelisted node IDs
    TypedSet.NodeIdSet private _whitelist;

    /// @notice Reference to the Committee contract
    ICommittee public committee;

    /// @notice Reference to the Nodes contract
    INodes public nodes;

    /**
     * @notice Emitted when the heartbeat interval is updated
     * @param oldInterval The previous heartbeat interval
     * @param newInterval The new heartbeat interval
     */
    event HeartbeatIntervalUpdated(Duration oldInterval, Duration newInterval);

    /**
     * @notice Emitted when a node is added to the whitelist
     * @param nodeId The ID of the whitelisted node
     */
    event NodeWhitelisted(NodeId indexed nodeId);

    /**
     * @notice Emitted when a node is removed from the whitelist
     * @param nodeId The ID of the removed node
     */
    event NodeRemovedFromWhitelist(NodeId indexed nodeId);

    /**
     * @notice Emitted when node data is removed from the contract
     * @param nodeId The ID of the node whose data was removed
     */
    event NodeDataRemoved(NodeId indexed nodeId);

    /**
     * @notice Emitted when a heartbeat is received from a node
     * @param nodeId The ID of the node sending the heartbeat
     * @param timestamp The timestamp when the heartbeat was received
     */
    event HeartbeatReceived(NodeId indexed nodeId, uint256 timestamp);

    /**
     * @notice Thrown when attempting to whitelist a node that is already whitelisted
     * @param nodeId The ID of the already whitelisted node
     */
    error NodeAlreadyWhitelisted(NodeId nodeId);

    /**
     * @notice Thrown when attempting to remove a node that is not in the whitelist
     * @param nodeId The ID of the node not found in the whitelist
     */
    error NodeNotWhitelisted(NodeId nodeId);

    /**
     * @notice Initializes the Status contract
     * @dev This function is called only once during contract deployment following the proxy pattern
     * @param initialAuthority The address of the initial access control authority
     * @param nodesAddress The address of the Nodes contract
     * @param committeeAddress The address of the Committee contract
     */
    function initialize(address initialAuthority, INodes nodesAddress, ICommittee committeeAddress)
        external
        override
        initializer
    {
        __AccessManaged_init(initialAuthority);
        nodes = nodesAddress;
        committee = committeeAddress;
        heartbeatInterval = Duration.wrap(DEFAULT_HEARTBEAT_INTERVAL);
    }

    /**
     * @notice Records a heartbeat from a node
     * @dev Only callable by addresses associated with active nodes
     * @dev Updates the node's last heartbeat timestamp and processes the heartbeat if the node is whitelisted
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
     * @dev Only callable by authorized addresses (restricted)
     * @param interval The new heartbeat interval duration
     */
    function setHeartbeatInterval(Duration interval) external override restricted {
        Duration oldInterval = heartbeatInterval;
        heartbeatInterval = interval;
        emit HeartbeatIntervalUpdated(oldInterval, interval);
    }

    /**
     * @notice Adds a node to the whitelist
     * @dev Only callable by authorized addresses (restricted)
     * @dev The node must exist (either active or passive) to be whitelisted
     * @dev If the node is active, notifies the committee of the whitelisting
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
     * @dev Only callable by authorized addresses (restricted)
     * @dev If the node is active, notifies the committee that the node was removed from the whitelist
     * @param nodeId The ID of the node to remove from the whitelist
     */
    function removeNodeFromWhitelist(NodeId nodeId) external override restricted {
        require(_whitelist.remove(nodeId), NodeNotWhitelisted(nodeId));
        bool isActive = nodes.activeNodeExists(nodeId);
        emit NodeRemovedFromWhitelist(nodeId);
        if (isActive) {
            committee.nodeRemovedFromWhitelist(nodeId);
        }
    }

    /**
     * @notice Cleans up data for a removed node
     * @dev Only callable by Nodes contract (restricted)
     * @dev Removes the node from the whitelist if present and deletes its heartbeat timestamp
     * @param nodeId The ID of the node that was removed
     */
    function nodeRemoved(NodeId nodeId) external override restricted {
        if (_whitelist.contains(nodeId)) {
            assert(_whitelist.remove(nodeId));
        }
        delete lastHeartbeatTimestamp[nodeId];
        emit NodeDataRemoved(nodeId);
    }

    /**
     * @notice Returns the list of all whitelisted nodes
     * @return nodeIds Array of whitelisted node IDs
     */
    function getWhitelistedNodes() external view override returns (NodeId[] memory nodeIds) {
        nodeIds = _whitelist.values();
    }

    /**
     * @notice Checks if a node is whitelisted
     * @param nodeId The ID of the node to check
     * @return whitelisted True if the node is whitelisted, false otherwise
     */
    function isWhitelisted(NodeId nodeId) public view override returns (bool whitelisted) {
        whitelisted = _whitelist.contains(nodeId);
    }

    /**
     * @notice Checks if a node is healthy
     * @dev A node is considered healthy if the time since its last heartbeat is less than the heartbeat interval
     * @param nodeId The ID of the node to check
     * @return healthy True if the node is healthy, false otherwise
     */
    function isHealthy(NodeId nodeId) public view override returns (bool healthy) {
        uint256 interval = block.timestamp - lastHeartbeatTimestamp[nodeId];
        healthy = interval < Duration.unwrap(heartbeatInterval);
    }
}

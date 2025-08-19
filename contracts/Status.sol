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

import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { ICommittee } from "@skalenetwork/fair-manager-interfaces/ICommittee.sol";
import { INodes, NodeId } from "@skalenetwork/fair-manager-interfaces/INodes.sol";
import { Duration, IStatus } from "@skalenetwork/fair-manager-interfaces/IStatus.sol";

import { TypedSet } from "./structs/typed/TypedSet.sol";


contract Status is AccessManagedUpgradeable, IStatus {

    using TypedSet for TypedSet.NodeIdSet;

    Duration public heartbeatInterval;
    mapping (NodeId id => uint256 timestamp) public lastHeartbeatTimestamp;
    TypedSet.NodeIdSet private _whitelist;

    ICommittee public committee;
    INodes public nodes;

    event HeartbeatIntervalUpdated(Duration oldInterval, Duration newInterval);
    event NodeWhitelisted(NodeId indexed nodeId);
    event NodeRemovedFromWhitelist(NodeId indexed nodeId);
    event NodeDataRemoved(NodeId indexed nodeId);
    event HeartbeatReceived(NodeId indexed nodeId, uint256 timestamp);

    error NodeAlreadyWhitelisted(NodeId nodeId);
    error NodeNotWhitelisted(NodeId nodeId);
    error NodeDoesNotExist(NodeId nodeId);

    function initialize(
        address initialAuthority,
        INodes nodesAddress,
        ICommittee committeeAddress
    )
        public
        override
        initializer
    {
        __AccessManaged_init(initialAuthority);
        nodes = nodesAddress;
        committee = committeeAddress;
        heartbeatInterval = Duration.wrap(5 minutes);
    }

    function alive() external override {
        // Nodes.sol will revert if sender has no Active Node
        NodeId nodeId = nodes.getNodeId(msg.sender);

        lastHeartbeatTimestamp[nodeId] = block.timestamp;
        emit HeartbeatReceived(nodeId, block.timestamp);

        if (isWhitelisted(nodeId)) {
            committee.processHeartbeat(nodeId);
        }
    }
    function setHeartbeatInterval(Duration interval) external override restricted {
        Duration oldInterval = heartbeatInterval;
        heartbeatInterval = interval;
        emit HeartbeatIntervalUpdated(oldInterval, interval);
    }

    function whitelistNode(NodeId nodeId) external override restricted {
        bool isActive = nodes.activeNodeExists(nodeId);
        require(
            isActive || nodes.passiveNodeExists(nodeId),
            NodeDoesNotExist(nodeId)
        );

        require(_whitelist.add(nodeId), NodeAlreadyWhitelisted(nodeId));
        emit NodeWhitelisted(nodeId);
        if (isActive) {
            committee.nodeWhitelisted(nodeId);
        }
    }

    function removeNodeFromWhitelist(NodeId nodeId) external override restricted {
        require(_whitelist.remove(nodeId), NodeNotWhitelisted(nodeId));
        bool isActive = nodes.activeNodeExists(nodeId);
        emit NodeRemovedFromWhitelist(nodeId);
        if (isActive) {
            committee.nodeBlacklisted(nodeId);
        }
    }

    function nodeRemoved(NodeId nodeId) external override restricted {
        if(_whitelist.contains(nodeId)){
            assert(_whitelist.remove(nodeId));
        }
        delete lastHeartbeatTimestamp[nodeId];
        emit NodeDataRemoved(nodeId);
    }

    function getWhitelistedNodes() external view override returns (NodeId[] memory nodeIds) {
        nodeIds = _whitelist.values();
    }

    function isWhitelisted(NodeId nodeId) public view override returns (bool whitelisted) {
        whitelisted = _whitelist.contains(nodeId);
    }

    function isHealthy(NodeId nodeId) public view override returns (bool healthy) {
        uint256 interval = block.timestamp - lastHeartbeatTimestamp[nodeId];
        healthy = interval < Duration.unwrap(heartbeatInterval);
    }
}

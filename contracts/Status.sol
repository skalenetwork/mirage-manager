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
    TypedSet.NodeIdSet private _activeWhitelist;
    TypedSet.NodeIdSet private _passiveWhitelist;

    ICommittee public committee;
    INodes public nodes;

    event HeartbeatIntervalUpdated(Duration oldInterval, Duration newInterval);
    event ActiveNodeWhitelisted(NodeId indexed nodeId);
    event ActiveNodeRemovedFromWhitelist(NodeId indexed nodeId);
    event PassiveNodeWhitelisted(NodeId indexed nodeId);
    event PassiveNodeRemovedFromWhitelist(NodeId indexed nodeId);
    event NodeDataRemoved(NodeId indexed nodeId);
    event HeartbeatReceived(NodeId indexed nodeId, uint256 timestamp);

    error NodeAlreadyWhitelisted(NodeId nodeId);
    error NodeNotWhitelisted(NodeId nodeId);
    error NodeDoesNotExist(NodeId nodeId);

    modifier activeNodeExists(NodeId nodeId) {
        require(nodes.activeNodeExists(nodeId), NodeDoesNotExist(nodeId));
        _;
    }

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
        if (nodes.activeNodeExists(nodeId)){
            require(_activeWhitelist.add(nodeId), NodeAlreadyWhitelisted(nodeId));
            emit ActiveNodeWhitelisted(nodeId);
            committee.nodeWhitelisted(nodeId);
        }
        else if (nodes.passiveNodeExists(nodeId)) {
            require(_passiveWhitelist.add(nodeId), NodeAlreadyWhitelisted(nodeId));
            emit PassiveNodeWhitelisted(nodeId);
        }
        else {
            revert NodeDoesNotExist(nodeId);
        }
    }

    function removeNodeFromWhitelist(NodeId nodeId) external override restricted {
        bool wasActive = _activeWhitelist.contains(nodeId);
        bool wasPassive = _passiveWhitelist.contains(nodeId);
        require(wasActive || wasPassive, NodeNotWhitelisted(nodeId));
        if (wasActive) {
            assert(_activeWhitelist.remove(nodeId));
            emit ActiveNodeRemovedFromWhitelist(nodeId);
            committee.nodeBlacklisted(nodeId);
        } else {
            assert(_passiveWhitelist.remove(nodeId));
            emit PassiveNodeRemovedFromWhitelist(nodeId);
        }
    }

    function nodeRemoved(NodeId nodeId) external override restricted {
        if(_activeWhitelist.contains(nodeId)){
            assert(_activeWhitelist.remove(nodeId));
        }
        else if(_passiveWhitelist.contains(nodeId)){
            assert(_passiveWhitelist.remove(nodeId));
        }
        delete lastHeartbeatTimestamp[nodeId];
        emit NodeDataRemoved(nodeId);
    }

    function getNodesEligibleForCommittee() external view override returns (NodeId[] memory nodeIds) {

        uint256 whitelistedLength = _activeWhitelist.length();
        NodeId[] memory healthyNodeIds = new NodeId[](whitelistedLength);
        uint256 eligibleCount = 0;

        for (uint256 i = 0; i < whitelistedLength; ++i) {
            NodeId nodeId = _activeWhitelist.at(i);

            if (isHealthy(nodeId)) {
                healthyNodeIds[eligibleCount] = nodeId;
                ++eligibleCount;
            }
        }

        nodeIds = new NodeId[](eligibleCount);
        for (uint256 i = 0; i < eligibleCount; ++i) {
            nodeIds[i] = healthyNodeIds[i];
        }
    }

    function getWhitelistedActiveNodes() external view override returns (NodeId[] memory nodeIds) {
        nodeIds = _activeWhitelist.values();
    }

    function getWhitelistedPassiveNodes() external view override returns (NodeId[] memory nodeIds) {
        nodeIds = _passiveWhitelist.values();
    }

    function isWhitelisted(NodeId nodeId) public view override returns (bool whitelisted) {
        whitelisted = _activeWhitelist.contains(nodeId);
    }

    function isPassiveWhitelisted(NodeId nodeId) public view override returns (bool whitelisted) {
        whitelisted = _passiveWhitelist.contains(nodeId);
    }

    function isHealthy(NodeId nodeId) public view override returns (bool healthy) {
        uint256 interval = block.timestamp - lastHeartbeatTimestamp[nodeId];
        healthy = interval < Duration.unwrap(heartbeatInterval);
    }
}

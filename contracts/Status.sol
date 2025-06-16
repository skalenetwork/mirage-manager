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
import { ICommittee } from "@skalenetwork/fair-interfaces/ICommittee.sol";
import { INodes, NodeId } from "@skalenetwork/fair-interfaces/INodes.sol";
import { Duration, IStatus } from "@skalenetwork/fair-interfaces/IStatus.sol";

import { TypedSet } from "./structs/typed/TypedSet.sol";


contract Status is AccessManagedUpgradeable, IStatus {

    using TypedSet for TypedSet.NodeIdSet;

    Duration public heartbeatInterval;
    mapping (NodeId id => uint256 timestamp) public lastHeartbeatTimestamp;
    TypedSet.NodeIdSet private _whitelist;

    ICommittee public committee;
    INodes public nodes;

    error NodeAlreadyWhitelisted(NodeId nodeId);
    error NodeNotWhitelisted(NodeId nodeId);
    error NodeDoesNotExist(NodeId nodeId);

    modifier nodeExists(NodeId nodeId) {
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

        if (isWhitelisted(nodeId)) {
            committee.processHeartbeat(nodeId);
        }
    }
    function setHeartbeatInterval(Duration interval) external override restricted {
        heartbeatInterval = interval;
    }

    function whitelistNode(NodeId nodeId) external override restricted nodeExists(nodeId) {
        require(_whitelist.add(nodeId), NodeAlreadyWhitelisted(nodeId));
        committee.nodeWhitelisted(nodeId);
    }

    function removeNodeFromWhitelist(NodeId nodeId) external override restricted {
        require(_whitelist.remove(nodeId), NodeNotWhitelisted(nodeId));
        committee.nodeBlacklisted(nodeId);
    }

    function getNodesEligibleForCommittee() external view override returns (NodeId[] memory nodeIds) {

        uint256 whitelistedLength = _whitelist.length();
        NodeId[] memory healthyNodeIds = new NodeId[](whitelistedLength);
        uint256 eligibleCount = 0;

        for (uint256 i = 0; i < whitelistedLength; ++i) {
            NodeId nodeId = _whitelist.at(i);

            // TODO: improve. It's simple enough while nodes can't be removed
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

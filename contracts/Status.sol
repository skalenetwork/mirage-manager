// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   Status.sol - playa-manager
 *   Copyright (C) 2025-Present SKALE Labs
 *   @author Dmytro Stebaiev
 *
 *   playa-manager is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as published
 *   by the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   playa-manager is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with playa-manager.  If not, see <https://www.gnu.org/licenses/>.
 */

pragma solidity ^0.8.24;

import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { INodes, NodeId } from "@skalenetwork/playa-manager-interfaces/contracts/INodes.sol";
import { Duration, IStatus } from "@skalenetwork/playa-manager-interfaces/contracts/IStatus.sol";

import { TypedSet } from "./structs/typed/TypedSet.sol";


contract Status is AccessManagedUpgradeable, IStatus {

    using TypedSet for TypedSet.NodeIdSet;

    Duration public heartbeatInterval;
    mapping (NodeId id => uint256 timestamp) public lastHeartbeatTimestamp;
    TypedSet.NodeIdSet private _whitelist;

    INodes public nodes;

    error NodeAlreadyWhitelisted(NodeId nodeId);
    error NodeNotWhitelisted(NodeId nodeId);
    error NodeDoesNotExist(NodeId nodeId);

    modifier nodeExists(NodeId nodeId) {
        require(nodes.activeNodeExists(nodeId), NodeDoesNotExist(nodeId));
        _;
    }
    function initialize(address initialAuthority, INodes nodesAddress) public override initializer {
        __AccessManaged_init(initialAuthority);
        nodes = nodesAddress;
    }

    function alive() external override {
        // Nodes.sol will revert if sender has no Active Node
        NodeId nodeId = nodes.getNodeId(msg.sender);

        lastHeartbeatTimestamp[nodeId] = block.timestamp;
    }
    function setHeartbeatInterval(Duration interval) external override restricted {
        heartbeatInterval = interval;
    }

    function whitelistNode(NodeId nodeId) external override restricted nodeExists(nodeId) {
        require(_whitelist.add(nodeId), NodeAlreadyWhitelisted(nodeId));
    }

    function removeNodeFromWhitelist(NodeId nodeId) external override restricted {
        require(_whitelist.remove(nodeId), NodeNotWhitelisted(nodeId));
    }

    function isHealthy(NodeId nodeId) external view override returns (bool healthy) {
        healthy = _isHealthy(nodeId);
    }

    function getNodesEligibleForCommittee() external view override returns (NodeId[] memory nodeIds) {
        uint256[] memory whitelistedIds = _whitelist.values();
        NodeId[] memory healthyNodeIds = new NodeId[](whitelistedIds.length);
        uint256 eligibleCount = 0;

        uint256 whitelistedLength = whitelistedIds.length;
        for (uint256 i = 0; i < whitelistedLength; ++i) {
            NodeId nodeId = NodeId.wrap(whitelistedIds[i]);

            // TODO: improve. It's simple enough while nodes can't be removed
            if (_isHealthy(nodeId)) {
                healthyNodeIds[eligibleCount] = nodeId;
                ++eligibleCount;
            }
        }

        nodeIds = new NodeId[](eligibleCount);
        for (uint256 i = 0; i < eligibleCount; ++i) {
            nodeIds[i] = healthyNodeIds[i];
        }
    }


    function getWhitelistedNodes() external view override returns (uint256[] memory nodeIds) {
        nodeIds = _whitelist.values();
    }

    function _isHealthy(NodeId nodeId) private view returns (bool healthy) {

        uint256 interval = block.timestamp - lastHeartbeatTimestamp[nodeId];

        // Disabling recommendation to not compare using block timestamps
        healthy = interval < Duration.unwrap(heartbeatInterval);
    }
}

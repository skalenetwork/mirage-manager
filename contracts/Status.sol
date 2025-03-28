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
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { INodes, NodeId } from "@skalenetwork/playa-manager-interfaces/contracts/INodes.sol";
import { Duration, IStatus } from "@skalenetwork/playa-manager-interfaces/contracts/IStatus.sol";



contract Status is AccessManagedUpgradeable, IStatus {

    using EnumerableSet for EnumerableSet.UintSet;

    Duration public heartbeatInterval;
    mapping (NodeId id => Duration timestamp) public lastHeartbeatTimestamp;
    EnumerableSet.UintSet private _whitelist;

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

        lastHeartbeatTimestamp[nodeId] = Duration.wrap(block.timestamp);
    }
    function setHeartbeatInterval(Duration interval) external override restricted {
        heartbeatInterval = interval;
    }

    function whitelistNode(NodeId nodeId) external override restricted nodeExists(nodeId) {
        require(_whitelist.add(NodeId.unwrap(nodeId)), NodeAlreadyWhitelisted(nodeId));
    }

    function removeNodeFromWhitelist(NodeId nodeId) external override restricted {
        require(_whitelist.remove(NodeId.unwrap(nodeId)), NodeNotWhitelisted(nodeId));
    }

    function isHealthy(NodeId nodeId) external view override returns (bool healthy) {
        healthy = _isHealthy(nodeId);
    }

    function getNodesEligibleForCommittee() external view override returns (NodeId[] memory nodeIds) {
        // TODO: Select random subset ?
        uint256[] memory ids = _whitelist.values();
        NodeId[] memory temp = new NodeId[](ids.length);
        uint256 count = 0;
        uint256 idsLength = ids.length;

        for (uint256 i = 0; i < idsLength; ++i) {
            NodeId nodeId = NodeId.wrap(ids[i]);
            if (!_isHealthy(nodeId)) {
                continue;
            }
            // Node may not exist anymore in repository, but external call in a loop seems costly
            // The other option would be to propagate node removals, but this introduces circular dependency
            // Disabling for now
            // slither-disable-next-line all
            if (nodes.activeNodeExists(nodeId)) {
                temp[count] = nodeId;
                ++count;
            }
        }

        nodeIds = new NodeId[](count);
        for (uint256 i = 0; i < count; ++i) {
            nodeIds[i] = temp[i];
        }
    }

    function getWhitelistedNodes() external view override returns (uint256[] memory nodeIds) {
        nodeIds = _whitelist.values();
    }

    function _isHealthy(NodeId nodeId) private view returns (bool healthy) {

        uint256 interval = block.timestamp - Duration.unwrap(lastHeartbeatTimestamp[nodeId]);

        // Disabling recommendation to not compare using block timestamps
        // slither-disable-next-line all
        healthy = interval < Duration.unwrap(heartbeatInterval);
    }
}

// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   Nodes.sol - playa-manager
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

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {INodes, NodeId} from "@skalenetwork/playa-manager-interfaces/contracts/INodes.sol";

contract Nodes is INodes {

    using EnumerableSet for EnumerableSet.UintSet;

    // For node Id generation
    uint256 private _nodeIdCounter;

    // Set to track passive node IDs
    EnumerableSet.UintSet private _passiveNodeIds;

    // Set to track active node IDs
    EnumerableSet.UintSet private _activeNodeIds;


    // Mapping from node ID to Node struct
    mapping(NodeId => Node) public nodes;

    error NodeDoesNotExist(NodeId nodeId);

    function registerNode(bytes calldata ip, uint256 port) external override {
        NodeId nodeId = NodeId.wrap(_nodeIdCounter);

        unchecked {
            ++_nodeIdCounter;
        }

        _addActiveNodeId(nodeId);

        nodes[nodeId] = Node({
            id: nodeId,
            port: port,
            // TODO: check/change? maybe receive as input
            nodeAddress: msg.sender,
            nodePublicKey: [bytes32(0), bytes32(0)],
            ip: ip
        });

        emit NodeRegistered(nodeId, msg.sender, ip, port);
    }

    function registerPassiveNode(
        bytes calldata ip,
        uint256 port
    ) external override {
        NodeId nodeId = NodeId.wrap(_nodeIdCounter);

        unchecked {
            ++_nodeIdCounter;
        }

        _addPassiveNodeId(nodeId);

        nodes[nodeId] = Node({
            id: nodeId,
            port: port,
            // TODO: check/change? maybe receive as input
            nodeAddress: msg.sender,
            nodePublicKey: [bytes32(0), bytes32(0)],
            ip: ip
        });

        emit NodeRegistered(nodeId, msg.sender, ip, port);
    }

    function getNode(NodeId nodeId)
        external
        view
        override
        returns (Node memory node)
    {
        _checkNodeIndex(nodeId);
        return nodes[nodeId];
    }


    function _addPassiveNodeId(NodeId nodeId) private {
        _passiveNodeIds.add(NodeId.unwrap(nodeId));
    }

    function _addActiveNodeId(NodeId nodeId) private {
        _activeNodeIds.add(NodeId.unwrap(nodeId));
    }

    function _checkNodeIndex(NodeId nodeId) private view {
        if (!_isActiveNode(nodeId) && !_isPassiveNode(nodeId)){
            revert NodeDoesNotExist(nodeId);
        }
    }

    function _isActiveNode(NodeId nodeId) private view returns (bool result) {
        result = _activeNodeIds.contains(NodeId.unwrap(nodeId));
    }

    function _isPassiveNode(NodeId nodeId) private view returns (bool result) {
        result = _passiveNodeIds.contains(NodeId.unwrap(nodeId));
    }

}

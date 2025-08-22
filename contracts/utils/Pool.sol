// SPDX-License-Identifier: AGPL-3.0-only

/*
    Pool.sol - fair-manager
    Copyright (C) 2025-Present SKALE Labs
    @author Dmytro Stebaiev

    fair-manager is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published
    by the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    fair-manager is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with fair-manager.  If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity ^0.8.24;

import { NodeId } from "@skalenetwork/fair-manager-interfaces/INodes.sol";
import { IStatus } from "@skalenetwork/fair-manager-interfaces/IStatus.sol";
import { SplayTree } from "../structs/SplayTree.sol";
import { TypedSet } from "../structs/typed/TypedSet.sol";
import { IRandom, Random } from "./Random.sol";

/// @title Library for managing set of eligible nodes
/// @author Dmytro Stebaiev
/// @notice Provides functions for managing set of eligible nodes
/// @dev Nodes are ordered by last alive() function call time
library PoolLibrary {
    using Random for IRandom.RandomGenerator;
    using SplayTree for mapping(NodeId => SplayTree.Node);
    using TypedSet for TypedSet.NodeIdSet;

    struct Pool {
        mapping (NodeId id => SplayTree.Node node) tree;
        NodeId root;
        TypedSet.NodeIdSet presentNodes;
        TypedSet.NodeIdSet incomingNodes;
        IStatus status;
    }

    error NodeIsMissing(NodeId id);
    error TooFewCandidates(
        uint256 needed,
        uint256 available
    );

    /// @notice Adds node to the pool
    /// @dev Adds to unordered part
    /// @param pool Pool struct
    /// @param id Node ID
    function add(Pool storage pool, NodeId id) internal {
        assert(pool.incomingNodes.add(id));
    }

    /// @notice Moves node to the front of the order
    /// @dev If node was in the unordered part, it moves to the ordered part
    /// @param pool Pool struct
    /// @param node Node ID
    /// @param weight Weight of the node
    function moveToFront(Pool storage pool, NodeId node, uint256 weight) internal {
        remove(pool, node);
        assert(pool.presentNodes.add(node));
        pool.root = pool.tree.insertSmallest(pool.root, node, weight);
    }

    /// @notice Removes node from the pool
    /// @param pool Pool struct
    /// @param node Node ID
    /// @return removed True if node was present and was removed and false otherwise
    function remove(Pool storage pool, NodeId node) internal returns (bool removed) {
        if (pool.presentNodes.remove(node)) {
            pool.root = pool.tree.remove(node);
            removed = true;
        } else {
            return pool.incomingNodes.remove(node);
        }
    }

    /// @notice Return random sample of nodes from the pool
    /// @dev Probability of choosing node is proportional to its weight
    /// @param pool Pool struct
    /// @param size Size of the sample
    /// @param generator Instance of RandomGenerator
    /// @return nodesSample Array of node IDs
    function sample(
        Pool storage pool,
        uint256 size,
        IRandom.RandomGenerator memory generator
    )
        internal
        returns (NodeId[] memory nodesSample)
    {
        nodesSample = new NodeId[](size);
        NodeId lastHealthy = _findLastHealthyNode(pool);
        require(lastHealthy != SplayTree.NULL, TooFewCandidates(size, 0));
        pool.root = pool.tree.splay(lastHealthy);
        uint256 totalWeight = pool.tree[lastHealthy].totalWeight
                - pool.tree[pool.tree[lastHealthy].right].totalWeight;
        for (uint256 i = 0; i < size; ++i) {
            require(totalWeight > 0, TooFewCandidates(size, i));
            uint256 randomValue = generator.random(totalWeight);
            NodeId choice = pool.tree.findByWeight(pool.root, randomValue);
            // findByWeight did splay
            uint256 weight = pool.tree[choice].totalWeight -
                (pool.tree[pool.tree[choice].left].totalWeight + pool.tree[pool.tree[choice].right].totalWeight);
            remove(pool, choice);
            add(pool, choice);
            nodesSample[i] = choice;
            totalWeight -= weight;
        }
    }

    /// @notice Sets weight of the node
    /// @param pool Pool struct
    /// @param node Node ID
    /// @param weight New weight
    function setWeight(
        Pool storage pool,
        NodeId node,
        uint256 weight
    ) internal {
        if (pool.presentNodes.contains(node)) {
            pool.root = pool.tree.setWeight(node, weight);
        }
    }

    /// @notice Gets one of the nodes that hasn't called the alive() function for the longest time
    /// @param pool Pool struct
    /// @return oldest Node ID or SplayTree.NULL if pool is empty
    function getOldestIsh(Pool storage pool) internal returns (NodeId oldest) {
        if (pool.incomingNodes.length() > 0) {
            return pool.incomingNodes.at(0);
        }
        if (pool.root == SplayTree.NULL) {
            return SplayTree.NULL;
        }
        pool.root = pool.tree.findLast(pool.root);
        return pool.root;
    }

    /// @notice Checks if node is in the pool
    /// @param pool Pool struct
    /// @param node Node ID
    /// @return present True if node is in the pool and false otherwise
    function contains(Pool storage pool, NodeId node) internal view returns (bool present) {
        return pool.presentNodes.contains(node) || pool.incomingNodes.contains(node);
    }

    /// @notice Gets number of nodes in the pool
    /// @param pool Pool struct
    /// @return poolSize Number of nodes in the pool
    function length(Pool storage pool) internal view returns (uint256 poolSize) {
        return pool.presentNodes.length() + pool.incomingNodes.length();
    }

    // Private

    /// @notice Finds healthy node in the pool that hasn't called the alive() function for the longest time
    /// @param pool Pool struct
    /// @return lastHealthy Node ID or SplayTree.NULL if there are no healthy nodes
    function _findLastHealthyNode(Pool storage pool) private view returns (NodeId lastHealthy) {
        lastHealthy = SplayTree.NULL;
        NodeId node = pool.root;
        IStatus status = pool.status;
        while (node != SplayTree.NULL) {
            if (status.isHealthy(node)) {
                lastHealthy = node;
                node = pool.tree[node].right;
            } else {
                node = pool.tree[node].left;
            }
        }
    }
}

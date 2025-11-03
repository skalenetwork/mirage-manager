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
import { RedBlackTree } from "../structs/RedBlackTree.sol";
import { TypedSet } from "../structs/typed/TypedSet.sol";
import { IRandom, Random } from "./Random.sol";

/**
 * @title Pool Library
 * @author SKALE Labs
 * @notice Library for managing a pool of nodes for committee selection
 * @dev Implements a two-tier pool structure: present nodes (in red-black tree) and incoming nodes (waiting heartbeat).
 * Uses weighted random sampling to select committee members fairly based on staking amounts.
 */
library PoolLibrary {
    using Random for IRandom.RandomGenerator;
    using RedBlackTree for mapping(NodeId => RedBlackTree.Node);
    using TypedSet for TypedSet.NodeIdSet;

    /// @notice Pool data structure with weighted tree and incoming nodes
    struct Pool {
        mapping (NodeId id => RedBlackTree.Node node) tree;
        NodeId root;
        TypedSet.NodeIdSet presentNodes;
        TypedSet.NodeIdSet incomingNodes;
        IStatus status;
    }

    /**
     * @dev Not enough healthy node candidates available for selection
     * @param needed The number of nodes needed
     * @param available The number of nodes available
     */
    error TooFewCandidates(
        uint256 needed,
        uint256 available
    );

    /**
     * @notice Adds a node to the incoming pool (waiting heartbeat)
     * @dev Should not be called if the node is already present in the tree
     * @param pool The pool storage
     * @param id The node ID to add
     */
    function add(Pool storage pool, NodeId id) internal {
        assert(pool.incomingNodes.add(id));
    }

    /**
     * @notice Moves a node to the front (leftmost position) of the weighted tree
     * @dev Removes the node if present, then inserts it with given weight
     * @param pool The pool storage
     * @param node The node ID to move
     * @param weight The weight value for the node
     */
    function moveToFront(Pool storage pool, NodeId node, uint256 weight) internal {
        remove(pool, node);
        assert(pool.presentNodes.add(node));
        pool.root = pool.tree.insertSmallest(pool.root, node, weight);
    }

    /**
     * @notice Removes a node from the pool (either present or incoming)
     * @dev Removes from the weighted tree if present, otherwise from incoming set
     * @param pool The pool storage
     * @param node The node ID to remove
     * @return removed True if the node was removed
     */
    function remove(Pool storage pool, NodeId node) internal returns (bool removed) {
        if (pool.presentNodes.remove(node)) {
            pool.root = pool.tree.remove(pool.root, node);
            removed = true;
        } else {
            return pool.incomingNodes.remove(node);
        }
    }

    /**
     * @notice Performs weighted random sampling of nodes from the pool to form a committee
     * @dev Only samples from healthy nodes.
     * @dev Selected nodes are moved to incoming set (require heartbeat for next selection).
     * @dev Uses cumulative weight-based selection for fairness.
     * @param pool The pool storage
     * @param size The number of nodes to sample
     * @param generator The random number generator instance
     * @return nodesSample Array of selected node IDs
     */
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
        require(lastHealthy != RedBlackTree.NULL, TooFewCandidates(size, 0));
        uint256 totalWeight = pool.tree.getWeightTill(lastHealthy);
        for (uint256 i = 0; i < size; ++i) {
            require(totalWeight > 0, TooFewCandidates(size, i));
            uint256 randomValue = generator.random(totalWeight);
            NodeId choice = pool.tree.findByWeight(pool.root, randomValue);
            uint256 weight = pool.tree.getWeight(choice);
            remove(pool, choice);
            add(pool, choice);
            nodesSample[i] = choice;
            totalWeight -= weight;
        }
    }

    /**
     * @notice Updates the weight of a node in the pool
     * @dev Only updates weight if the node is in the present node's pool, otherwise irrelevant
     * @param pool The pool storage
     * @param node The node ID to update
     * @param weight The new weight value
     */
    function setWeight(
        Pool storage pool,
        NodeId node,
        uint256 weight
    ) internal {
        if (pool.presentNodes.contains(node)) {
            pool.tree.setWeight(node, weight);
        }
    }

    /**
     * @notice Gets an approximate oldest node from the pool
     * @dev Returns first incoming node if any, otherwise the rightmost (oldest) node in tree
     * @param pool The pool storage
     * @return oldest The oldest-ish node ID, or NULL if pool is empty
     */
    function getOldestIsh(Pool storage pool) internal view returns (NodeId oldest) {
        if (pool.incomingNodes.length() > 0) {
            return pool.incomingNodes.at(0);
        }
        if (pool.root == RedBlackTree.NULL) {
            return RedBlackTree.NULL;
        }
        return pool.tree.findLast(pool.root);
    }

    /**
     * @notice Checks if a node is in the pool
     * @dev Searches both the active tree and incoming set
     * @param pool The pool storage
     * @param node The node ID to check
     * @return present True if the node is in the pool
     */
    function contains(Pool storage pool, NodeId node) internal view returns (bool present) {
        return pool.presentNodes.contains(node) || pool.incomingNodes.contains(node);
    }

    /**
     * @notice Returns the total number of nodes in the pool
     * @dev Sums present nodes and incoming nodes
     * @param pool The pool storage
     * @return poolSize The total number of nodes
     */
    function length(Pool storage pool) internal view returns (uint256 poolSize) {
        return pool.presentNodes.length() + pool.incomingNodes.length();
    }

    // private

    /**
     * @notice Finds the oldest node in the tree
     * @param pool The pool storage
     * @return lastHealthy The last healthy node, or NULL if none found
     */
    function _findLastHealthyNode(Pool storage pool) private view returns (NodeId lastHealthy) {
        lastHealthy = RedBlackTree.NULL;
        NodeId node = pool.root;
        IStatus status = pool.status;
        while (node != RedBlackTree.NULL) {
            if (status.isHealthy(node)) {
                lastHealthy = node;
                node = pool.tree[node].right;
            } else {
                node = pool.tree[node].left;
            }
        }
    }
}

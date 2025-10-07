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
 * @title PoolLibrary
 * @notice Library for managing a pool of nodes with weighted sampling and operations
 */
library PoolLibrary {

    using Random for IRandom.RandomGenerator;
    using RedBlackTree for mapping(NodeId => RedBlackTree.Node);
    using TypedSet for TypedSet.NodeIdSet;

    struct Pool {
        mapping(NodeId id => RedBlackTree.Node node) tree;
        NodeId root;
        TypedSet.NodeIdSet presentNodes;
        TypedSet.NodeIdSet incomingNodes;
        IStatus status;
    }

    error NodeIsMissing(NodeId id);
    error TooFewCandidates(uint256 needed, uint256 available);

    /**
     * @notice Adds a node to the incoming nodes set of the pool
     * @dev Asserts the node is newly added to the incomingNodes set.
     * @param pool The pool to which the node is added
     * @param id The ID of the node to add
     */
    function add(Pool storage pool, NodeId id) internal {
        assert(pool.incomingNodes.add(id));
    }

    /**
     * @notice Moves a node to the front of the pool with a specified weight
     * @dev Removes the node from its current position and re-inserts it with the given weight.
     * @param pool The pool containing the node
     * @param node The ID of the node to move
     * @param weight The weight to assign to the node
     */
    function moveToFront(Pool storage pool, NodeId node, uint256 weight) internal {
        remove(pool, node);
        assert(pool.presentNodes.add(node));
        pool.root = pool.tree.insertSmallest(pool.root, node, weight);
    }

    /**
     * @notice Removes a node from the pool
     * @dev Removes the node from either the presentNodes or incomingNodes set of the pool.
     * @param pool The pool from which the node is removed
     * @param node The ID of the node to remove
     * @return removed True if the node was removed, false otherwise
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
     * @notice Samples a specified number of nodes from the pool
     * @dev Uses a random generator to select a set of nodes using weighted-random selection.
     * @param pool The pool to sample from
     * @param size The number of nodes to sample
     * @param generator The random generator instance
     * @return nodesSample An array of sampled node IDs
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
     * @notice Sets the weight of a node in the pool
     * @dev Updates the weight of the node if it is in the presentNodes set.
     * @param pool The pool containing the node
     * @param node The ID of the node to update
     * @param weight The new weight to assign to the node
     */
    function setWeight(Pool storage pool, NodeId node, uint256 weight) internal {
        if (pool.presentNodes.contains(node)) {
            pool.tree.setWeight(node, weight);
        }
    }

    /**
     * @notice Retrieves the oldest node in the pool
     * @dev Returns the first node in the incomingNodes set or the last node in the tree.
     * @param pool The pool to query
     * @return oldest The ID of the oldest node
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
     * @notice Checks if a node is present in the pool
     * @dev Verifies if the node is in either the presentNodes or incomingNodes set.
     * @param pool The pool to query
     * @param node The ID of the node to check
     * @return present True if the node is present, false otherwise
     */
    function contains(Pool storage pool, NodeId node) internal view returns (bool present) {
        return pool.presentNodes.contains(node) || pool.incomingNodes.contains(node);
    }

    /**
     * @notice Retrieves the total number of nodes in the pool
     * @dev Calculates the sum of nodes in the presentNodes and incomingNodes sets.
     * @param pool The pool to query
     * @return poolSize The total number of nodes in the pool
     */
    function length(Pool storage pool) internal view returns (uint256 poolSize) {
        return pool.presentNodes.length() + pool.incomingNodes.length();
    }

    // private

    /**
     * @notice Finds the last healthy node in the pool
     * @dev Traverses the tree to find the last node marked as healthy by the status contract.
     * @param pool The pool to query
     * @return lastHealthy The ID of the last healthy node
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

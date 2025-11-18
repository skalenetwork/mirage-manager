// SPDX-License-Identifier: AGPL-3.0-only

/*
    RedBlackTreeTester.sol - fair-manager
    Copyright (C) 2025-Present SKALE Labs
    @author Dmytro Stebaiev
    @author Eduardo Vasques

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

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {NodeId} from "@skalenetwork/fair-manager-interfaces/INodes.sol";
import {RedBlackTree} from "../../structs/RedBlackTree.sol";

/**
 * @title IRedBlackTreeTester
 * @author Dmytro Stebaiev
 * @author Eduardo Vasques
 * @notice Interface for the RedBlackTreeTester contract
 * @dev Provides testing functions for Red-Black Tree operations
 */
interface IRedBlackTreeTester {
    /**
     * @notice Inserts a new node with the smallest ID into the tree
     * @param node The node ID to insert
     * @param weight The weight associated with the node
     */
    function insertSmallest(NodeId node, uint256 weight) external;

    /**
     * @notice Removes a node from the tree
     * @param node The node ID to remove
     */
    function remove(NodeId node) external;

    /**
     * @notice Updates the weight of a node in the tree
     * @param node The node ID whose weight to update
     * @param weight The new weight value
     */
    function setWeight(NodeId node, uint256 weight) external;

    /**
     * @notice Gets all nodes in the tree
     * @return nodes Array of node IDs in the tree
     */
    function getNodes() external view returns (NodeId[] memory nodes);

    /**
     * @notice Validates the Red-Black Tree properties
     * @return result True if all properties are valid, reverts otherwise
     */
    function validate() external view returns (bool result);

    /**
     * @notice Gets the total number of nodes in the tree
     * @return numNodes The count of nodes in the tree
     */
    function getNumNodes() external view returns (uint256 numNodes);
}

/**
 * @title RedBlackTreeTester
 * @author Dmytro Stebaiev
 * @author Eduardo Vasques
 * @notice Test harness for Red-Black Tree operations
 * @dev Provides testing and validation functions for the RedBlackTree Library
 */
contract RedBlackTreeTester is IRedBlackTreeTester {
    using RedBlackTree for mapping(NodeId => RedBlackTree.Node);
    using Strings for uint256;

    /// @notice Constant representing a null node reference
    NodeId public constant NULL = RedBlackTree.NULL;

    /// @notice Constant representing an empty node reference
    NodeId public constant EMPTY = NodeId.wrap(type(uint256).max);

    /// @notice Mapping from node ID to node data
    mapping(NodeId node => RedBlackTree.Node data) public tree;

    /// @notice Mapping from node ID to its weight
    mapping(NodeId node => uint256 weight) public weights;

    /// @notice The root node of the tree
    NodeId public root;

    /**
     * @dev Thrown when black height is inconsistent with left and right subtrees
     * @param node The node where the inconsistency was detected
     * @param leftBlackHeight The black height of the left subtree
     * @param rightBlackHeight The black height of the right subtree
     */
    error IncorrectBlackHeight(NodeId node, uint256 leftBlackHeight, uint256 rightBlackHeight);

    /**
     * @dev Thrown when a left child's parent reference is incorrect
     * @param parent The expected parent node
     * @param child The left child node
     * @param actualParent The actual parent stored in the child
     */
    error IncorrectParentOfLeftChild(NodeId parent, NodeId child, NodeId actualParent);

    /**
     * @dev Thrown when a right child's parent reference is incorrect
     * @param parent The expected parent node
     * @param child The right child node
     * @param actualParent The actual parent stored in the child
     */
    error IncorrectParentOfRightChild(NodeId parent, NodeId child, NodeId actualParent);

    /**
     * @dev Thrown when a red node has a red left child (Red-Black Tree property violation)
     * @param node The red node
     * @param redChild The red left child
     */
    error RedNodeHasRedLeftChild(NodeId node, NodeId redChild);

    /**
     * @dev Thrown when a red node has a red right child (Red-Black Tree property violation)
     * @param node The red node
     * @param redChild The red right child
     */
    error RedNodeHasRedRightChild(NodeId node, NodeId redChild);

    /**
     * @dev Thrown when the root node has a non-null parent
     * @param root The root node
     * @param parent The incorrect parent reference
     */
    error RootHasParent(NodeId root, NodeId parent);

    /**
     * @dev Thrown when the root node is not black (Red-Black Tree property violation)
     * @param root The red root node
     */
    error RootIsNotBlack(NodeId root);

    /**
     * @dev Thrown when the total weight stored in a node doesn't match the calculated weight
     * @param node The node with incorrect weight
     * @param expected The expected total weight
     * @param actual The actual stored total weight
     */
    error TotalWeightIsIncorrect(NodeId node, uint256 expected, uint256 actual);

    /**
     * @notice Inserts a new node into the tree
     * @dev Updates the root and stores the node's weight
     * @param node The node ID to insert
     * @param weight The weight associated with the node
     */
    function insertSmallest(NodeId node, uint256 weight) external override {
        root = tree.insertSmallest(root, node, weight);
        weights[node] = weight;
    }

    /**
     * @notice Removes a node from the tree
     * @dev Updates the root after removal
     * @param node The node ID to remove
     */
    function remove(NodeId node) external override {
        root = tree.remove(root, node);
    }

    /**
     * @notice Updates the weight of a node in the tree
     * @dev Stores the weight and updates the tree structure
     * @param node The node ID whose weight to update
     * @param weight The new weight value
     */
    function setWeight(NodeId node, uint256 weight) external override {
        weights[node] = weight;
        tree.setWeight(node, weight);
    }

    /**
     * @notice Validates Red-Black Tree properties
     * @return result True if all properties are valid, reverts if validation fails
     */
    function validate() external view override returns (bool result) {
        if (root == NULL) {
            return true;
        }
        require(_isBlack(root), RootIsNotBlack(root));
        require(tree[root].parent == NULL, RootHasParent(root, tree[root].parent));
        _validate(root);
        return true;
    }

    /**
     * @notice Gets all nodes in the tree
     * @dev Performs an in-order traversal to collect all node IDs
     * @return nodes Array of node IDs
     */
    function getNodes() external view override returns (NodeId[] memory nodes) {
        nodes = new NodeId[](_count(root));
        _getNodes(root, nodes, 0);
    }

    /**
     * @notice Gets the total number of nodes in the tree
     * @return numNodes The count of nodes in the tree
     */
    function getNumNodes() external view override returns (uint256 numNodes) {
        return _count(root);
    }

    // private

    /**
     * @notice Checks if a node is black
     * @dev Returns true if node is black or null (null nodes are considered black)
     * @param node The node to check
     * @return black True if the node is black, false if red
     */
    function _isBlack(NodeId node) private view returns (bool black) {
        return !_isRed(node);
    }

    /**
     * @notice Checks if a node is red
     * @dev Returns false for null nodes
     * @param node The node to check
     * @return red True if the node is red, false if black or null
     */
    function _isRed(NodeId node) private view returns (bool red) {
        if (node == NULL) {
            return false;
        }
        return tree[node].red;
    }

    /**
     * @notice Performs an in-order traversal to collect all node IDs
     * @dev Recursively traverses left subtree, visits current node, then right subtree
     * @param node The current node being visited
     * @param nodes The array to populate with node IDs
     * @param index The current index in the nodes array
     * @return newIndex The updated index after processing this node and its subtrees
     */
    function _getNodes(NodeId node, NodeId[] memory nodes, uint256 index) private view returns (uint256 newIndex) {
        if (node == NULL) {
            return index;
        }
        index = _getNodes(tree[node].left, nodes, index);
        nodes[index] = node;
        ++index;
        index = _getNodes(tree[node].right, nodes, index);
        return index;
    }

    /**
     * @notice Counts the total number of nodes in a subtree
     * @dev Recursively counts nodes in left and right subtrees
     * @param node The root of the subtree to count
     * @return value The total number of nodes in the subtree
     */
    function _count(NodeId node) private view returns (uint256 value) {
        if (node == NULL) {
            return 0;
        } else {
            return 1 + _count(tree[node].left) + _count(tree[node].right);
        }
    }

    /**
     * @notice Recursively validates Red-Black Tree properties for a subtree
     * @dev Validates parent pointers, color constraints, black height, and total weight
     * @param currentRoot The root of the subtree to validate
     * @return blackHeight The black height of the subtree
     * @return weight The total weight of the subtree
     */
    function _validate(NodeId currentRoot) private view returns (uint256 blackHeight, uint256 weight) {
        if (currentRoot == NULL) {
            return (1, 0);
        }
        NodeId left = tree[currentRoot].left;
        NodeId right = tree[currentRoot].right;

        if (left != NULL) {
            require(tree[left].parent == currentRoot, IncorrectParentOfLeftChild(currentRoot, left, tree[left].parent));
        }
        if (right != NULL) {
            require(
                tree[right].parent == currentRoot, IncorrectParentOfRightChild(currentRoot, right, tree[right].parent)
            );
        }

        if (_isRed(currentRoot)) {
            require(_isBlack(left), RedNodeHasRedLeftChild(currentRoot, left));
            require(_isBlack(right), RedNodeHasRedRightChild(currentRoot, right));
        }

        (uint256 leftBlackHeight, uint256 leftWeight) = _validate(left);
        (uint256 rightBlackHeight, uint256 rightWeight) = _validate(right);
        require(
            leftBlackHeight == rightBlackHeight, IncorrectBlackHeight(currentRoot, leftBlackHeight, rightBlackHeight)
        );
        require(
            leftWeight + rightWeight + weights[currentRoot] == tree[currentRoot].totalWeight,
            TotalWeightIsIncorrect(
                currentRoot, leftWeight + rightWeight + weights[currentRoot], tree[currentRoot].totalWeight
            )
        );

        blackHeight = leftBlackHeight;
        if (_isBlack(currentRoot)) {
            ++blackHeight;
        }
        weight = tree[currentRoot].totalWeight;
    }
}

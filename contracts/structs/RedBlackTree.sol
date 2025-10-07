// SPDX-License-Identifier: AGPL-3.0-only

/*
    RedBlackTree.sol - fair-manager
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

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { NodeId } from "@skalenetwork/fair-manager-interfaces/INodes.sol";

/**
 * @title RedBlackTree
 * @notice A library for handling Red-Black Tree data structures.
 */
library RedBlackTree {

    using SafeCast for uint256;

    struct Node {
        NodeId id;
        NodeId parent;
        NodeId left;
        NodeId right;
        uint248 totalWeight;
        bool red;
    }

    /// @notice Represents a null node in the tree.
    NodeId public constant NULL = NodeId.wrap(0);

    error ChildIsMissing(NodeId node, NodeId child);
    error InsertNullNode();
    error NotFound();
    error RemoveNullNode();
    error SetWeightOfNullNode();

    /**
     * @notice Inserts a node into the top of the tree.
     * @param nodes The mapping of nodes in the tree.
     * @param root The root of the tree.
     * @param newNode The new node to insert.
     * @param weight The weight of the new node.
     * @return newRoot The new root of the tree.
     */
    function insertSmallest(
        mapping(NodeId => Node) storage nodes,
        NodeId root,
        NodeId newNode,
        uint256 weight
    )
        internal
        returns (NodeId newRoot)
    {
        require(newNode != NULL, InsertNullNode());
        uint248 weight_ = weight.toUint248();
        if (root == NULL) {
            _createNode(nodes, newNode, NULL, weight_);
            _setBlack(nodes, newNode);
            return newNode;
        }

        NodeId node;
        for (node = root; nodes[node].left != NULL; node = nodes[node].left) {
            nodes[node].totalWeight += weight_;
        }

        nodes[node].totalWeight += weight_;
        _createNode(nodes, newNode, node, weight_);
        nodes[node].left = newNode;

        return _balance(nodes, root, newNode);
    }

    /**
     * @notice Removes a node from the tree.
     * @param nodes The mapping of nodes in the tree.
     * @param root The root of the tree.
     * @param node The node to remove.
     * @return newRoot The new root of the tree.
     */
    function remove(
        mapping(NodeId => Node) storage nodes,
        NodeId root,
        NodeId node
    )
        internal
        returns (NodeId newRoot)
    {
        require(node != NULL, RemoveNullNode());
        NodeId left = nodes[node].left;
        NodeId right = nodes[node].right;

        if (left != NULL && right != NULL) {
            NodeId biggestChild = findLast(nodes, left);
            _swap(nodes, node, biggestChild);
            NodeId currentRoot = node == root ? biggestChild : root;
            if (nodes[biggestChild].parent == NULL) {
                currentRoot = biggestChild;
            }
            return remove(nodes, currentRoot, node);
        }
        setWeight(nodes, node, 0);
        if (left == NULL && right == NULL) {
            if (nodes[node].red) {
                return _removeRedLeaf(nodes, root, node);
            }
            return _removeBlackLeaf(nodes, root, node);
        } else {
            NodeId child = left == NULL ? right : left;
            assert(_isBlack(nodes, node));
            assert(_isRed(nodes, child));
            _updateChild(nodes, nodes[node].parent, node, child);
            nodes[child].red = false;
            delete nodes[node];
            if (nodes[child].parent == NULL) {
                return child;
            } else {
                return root;
            }
        }
    }

    /**
     * @notice Updates the weight of a node in the tree.
     * @param nodes The mapping of nodes in the tree.
     * @param node The node to set the weight of.
     * @param weight The new weight of the node.
     */
    function setWeight(mapping(NodeId => Node) storage nodes, NodeId node, uint256 weight) internal {
        require(node != NULL, SetWeightOfNullNode());
        uint248 oldWeight = getWeight(nodes, node);
        while (node != NULL) {
            nodes[node].totalWeight = nodes[node].totalWeight - oldWeight + weight.toUint248();
            node = nodes[node].parent;
        }
    }

    /**
     * @notice Finds a node in the tree by its weight.
     * @param nodes The mapping of nodes in the tree.
     * @param root The root of the tree.
     * @param weight The weight to search for.
     * @return node The node with the specified weight.
     */
    function findByWeight(
        mapping(NodeId => Node) storage nodes,
        NodeId root,
        uint256 weight
    )
        internal
        view
        returns (NodeId node)
    {
        node = root;
        while (node != NULL) {
            NodeId left = nodes[node].left;
            if (weight < _getTotalWeight(nodes, left)) {
                node = left;
            } else {
                NodeId right = nodes[node].right;
                uint256 leftAndNodeWeight = nodes[node].totalWeight - _getTotalWeight(nodes, right);
                if (weight < leftAndNodeWeight) {
                    return node;
                } else {
                    weight -= leftAndNodeWeight;
                    node = right;
                }
            }
        }
        revert NotFound();
    }

    /**
     * @notice Gets the rightmost node in the tree.
     * @param nodes The mapping of nodes in the tree.
     * @param root The root of the tree.
     * @return biggest The rightmost node in the tree.
     */
    function findLast(mapping(NodeId => Node) storage nodes, NodeId root) internal view returns (NodeId biggest) {
        for (NodeId node = root; node != NULL; node = nodes[node].right) {
            if (nodes[node].right == NULL) {
                return node;
            }
        }
        revert NotFound();
    }

    /**
     * @notice Gets the weight of a node.
     * @param nodes The mapping of nodes in the tree.
     * @param node The node to get the weight of.
     * @return weight The weight of the node.
     */
    function getWeight(mapping(NodeId => Node) storage nodes, NodeId node) internal view returns (uint248 weight) {
        if (node == NULL) {
            return 0;
        }
        weight = nodes[node].totalWeight;
        NodeId left = nodes[node].left;
        NodeId right = nodes[node].right;
        if (left != NULL) {
            weight -= nodes[left].totalWeight;
        }
        if (right != NULL) {
            weight -= nodes[right].totalWeight;
        }
    }

    /**
     * @notice Gets the weight of the tree up to a certain node.
     * @param nodes The mapping of nodes in the tree.
     * @param bound The node to get the weight up to.
     * @return weight The weight of the tree up to the specified node.
     */
    function getWeightTill(
        mapping(NodeId => Node) storage nodes,
        NodeId bound
    )
        internal
        view
        returns (uint256 weight)
    {
        weight = nodes[bound].totalWeight;
        if (nodes[bound].right != NULL) {
            weight -= nodes[nodes[bound].right].totalWeight;
        }

        NodeId node = bound;
        NodeId parent = nodes[bound].parent;
        while (parent != NULL) {
            if (nodes[parent].right == node) {
                weight += nodes[parent].totalWeight - nodes[node].totalWeight;
            }
            node = parent;
            parent = nodes[node].parent;
        }
        return weight;
    }

    // Private

    /**
     * @notice Balances the tree after an insertion.
     * @param nodes The mapping of nodes in the tree.
     * @param root The root of the tree.
     * @param node The node to balance from.
     * @return newRoot The new root of the tree.
     */
    function _balance(
        mapping(NodeId => Node) storage nodes,
        NodeId root,
        NodeId node
    )
        private
        returns (NodeId newRoot)
    {
        while (node != root) {
            NodeId parent = _parent(nodes, node);
            if (_isBlack(nodes, parent)) {
                return root;
            }
            NodeId uncle = _uncle(nodes, node);
            NodeId grandfather = _grandfather(nodes, node);
            if (_isRed(nodes, uncle)) {
                _setBlack(nodes, parent);
                _setBlack(nodes, uncle);
                _setRed(nodes, grandfather);
                node = grandfather;
            } else {
                assert(parent == nodes[grandfather].left);
                assert(node == nodes[parent].left);
                _rotateLeft(nodes, grandfather, parent);
                _setBlack(nodes, parent);
                _setRed(nodes, grandfather);
                return grandfather == root ? parent : root;
            }
        }
        if (_isRed(nodes, node)) {
            _setBlack(nodes, node);
        }
        return node;
    }

    /**
     * @notice Creates a new node in the tree.
     * @param nodes The mapping of nodes in the tree.
     * @param id The ID of the new node.
     * @param parent The parent of the new node.
     * @param weight The weight of the new node.
     */
    function _createNode(mapping(NodeId => Node) storage nodes, NodeId id, NodeId parent, uint248 weight) private {
        nodes[id] = Node({ id: id, parent: parent, left: NULL, right: NULL, totalWeight: weight, red: true });
    }

    /**
     * @notice Removes a black leaf from the tree.
     * @param nodes The mapping of nodes in the tree.
     * @param root The root of the tree.
     * @param node The node to remove.
     * @return newRoot The new root of the tree.
     */
    function _removeBlackLeaf(
        mapping(NodeId => Node) storage nodes,
        NodeId root,
        NodeId node
    )
        private
        returns (NodeId newRoot)
    {
        if (node == root) {
            delete nodes[node];
            return NULL;
        }
        NodeId parent = nodes[node].parent;
        delete nodes[node];
        _updateChild(nodes, parent, node, NULL);
        node = NULL;
        bool success;
        while (node != root) {
            if (nodes[parent].left == node) {
                (newRoot, success) = _fixBlackHeightLeftNode(nodes, root, parent);
                if (success) {
                    return newRoot;
                }
            } else {
                (newRoot, success) = _fixBlackHeightRightNode(nodes, root, parent);
                if (success) {
                    return newRoot;
                }
            }
            node = parent;
            parent = nodes[node].parent;
        }
    }

    /**
     * @notice Removes a red leaf from the tree.
     * @param nodes The mapping of nodes in the tree.
     * @param root The root of the tree.
     * @param node The node to remove.
     * @return newRoot The new root of the tree.
     */
    function _removeRedLeaf(
        mapping(NodeId => Node) storage nodes,
        NodeId root,
        NodeId node
    )
        private
        returns (NodeId newRoot)
    {
        _updateChild(nodes, nodes[node].parent, node, NULL);
        delete nodes[node];
        if (node == root) {
            return NULL;
        }
        return root;
    }

    /**
     * @notice Fixes the black height of the tree.
     * @param nodes The mapping of nodes in the tree.
     * @param root The root of the tree.
     * @param parent The parent of the removed node.
     * @return newRoot The new root of the tree.
     * @return success True if the black height was fixed, false otherwise.
     */
    function _fixBlackHeightRightNode(
        mapping(NodeId => Node) storage nodes,
        NodeId root,
        NodeId parent
    )
        private
        returns (NodeId newRoot, bool success)
    {
        NodeId sibling = nodes[parent].left;
        if (_isRed(nodes, parent)) {
            return (_fixBlackHeightRightNodeRedParent(nodes, root, parent, sibling), true);
        } else {
            return _fixBlackHeightRightNodeBlackParent(nodes, root, parent, sibling);
        }
    }

    /**
     * @notice Fixes the black height of the tree.
     * @param nodes The mapping of nodes in the tree.
     * @param root The root of the tree.
     * @param parent The parent of the removed node.
     * @return newRoot The new root of the tree.
     * @return success True if the black height was fixed, false otherwise.
     */
    function _fixBlackHeightLeftNode(
        mapping(NodeId => Node) storage nodes,
        NodeId root,
        NodeId parent
    )
        private
        returns (NodeId newRoot, bool success)
    {
        NodeId sibling = nodes[parent].right;
        if (_isRed(nodes, parent)) {
            return (_fixBlackHeightLeftNodeRedParent(nodes, root, parent, sibling), true);
        } else {
            return _fixBlackHeightLeftNodeBlackParent(nodes, root, parent, sibling);
        }
    }

    /**
     * @notice Fixes the black height of the tree after a right node removal with a red parent.
     * @param nodes The mapping of nodes in the tree.
     * @param root The root of the tree.
     * @param parent The parent of the removed node.
     * @param sibling The sibling of the removed node.
     * @return newRoot The new root of the tree.
     */
    function _fixBlackHeightRightNodeRedParent(
        mapping(NodeId => Node) storage nodes,
        NodeId root,
        NodeId parent,
        NodeId sibling
    )
        private
        returns (NodeId newRoot)
    {
        assert(_isBlack(nodes, sibling));
        NodeId left = nodes[sibling].left;
        NodeId right = nodes[sibling].right;

        if (_isRed(nodes, left)) {
            _rotateLeft(nodes, parent, sibling);

            _setBlack(nodes, parent);
            _setRed(nodes, sibling);
            _setBlack(nodes, left);

            if (parent == root) {
                return sibling;
            } else {
                return root;
            }
        } else if (_isRed(nodes, right)) {
            _rotateLeftRight(nodes, parent, sibling, right);

            _setBlack(nodes, parent);

            if (parent == root) {
                return right;
            } else {
                return root;
            }
        } else {
            _setBlack(nodes, parent);
            _setRed(nodes, sibling);
            return root;
        }
    }

    /**
     * @notice Fixes the black height of the tree after a left node removal with a red parent.
     * @param nodes The mapping of nodes in the tree.
     * @param root The root of the tree.
     * @param parent The parent of the removed node.
     * @param sibling The sibling of the removed node.
     * @return newRoot The new root of the tree.
     */
    function _fixBlackHeightLeftNodeRedParent(
        mapping(NodeId => Node) storage nodes,
        NodeId root,
        NodeId parent,
        NodeId sibling
    )
        private
        returns (NodeId newRoot)
    {
        assert(_isBlack(nodes, sibling));
        NodeId left = nodes[sibling].left;
        NodeId right = nodes[sibling].right;

        if (_isRed(nodes, left)) {
            _rotateRightLeft(nodes, parent, sibling, left);

            _setBlack(nodes, parent);

            if (parent == root) {
                return sibling;
            } else {
                return root;
            }
        } else if (_isRed(nodes, right)) {
            _rotateRight(nodes, parent, sibling);

            _setBlack(nodes, parent);
            _setRed(nodes, sibling);
            _setBlack(nodes, right);

            if (parent == root) {
                return right;
            } else {
                return root;
            }
        } else {
            _setBlack(nodes, parent);
            _setRed(nodes, sibling);
            return root;
        }
    }

    /**
     * @notice Fixes the black height of the tree after a right node removal with a black parent.
     * @param nodes The mapping of nodes in the tree.
     * @param root The root of the tree.
     * @param parent The parent of the removed node.
     * @param sibling The sibling of the removed node.
     * @return newRoot The new root of the tree.
     * @return success True if the black height was fixed, false otherwise.
     */
    function _fixBlackHeightRightNodeBlackParent(
        mapping(NodeId => Node) storage nodes,
        NodeId root,
        NodeId parent,
        NodeId sibling
    )
        private
        returns (NodeId newRoot, bool success)
    {
        if (_isRed(nodes, sibling)) {
            return (_fixBlackHeightRightNodeBlackParentRedSibling(nodes, root, parent, sibling), true);
        }
        return _fixBlackHeightRightNodeBlackParentBlackSibling(nodes, root, parent, sibling);
    }

    /**
     * @notice Fixes the black height of the tree after a left node removal with a black parent.
     * @param nodes The mapping of nodes in the tree.
     * @param root The root of the tree.
     * @param parent The parent of the removed node.
     * @param sibling The sibling of the removed node.
     * @return newRoot The new root of the tree.
     * @return success True if the black height was fixed, false otherwise.
     */
    function _fixBlackHeightLeftNodeBlackParent(
        mapping(NodeId => Node) storage nodes,
        NodeId root,
        NodeId parent,
        NodeId sibling
    )
        private
        returns (NodeId newRoot, bool success)
    {
        if (_isRed(nodes, sibling)) {
            return (_fixBlackHeightLeftNodeBlackParentRedSibling(nodes, root, parent, sibling), true);
        }
        return _fixBlackHeightLeftNodeBlackParentBlackSibling(nodes, root, parent, sibling);
    }

    /**
     * @notice Fixes the black height of the tree after a right node removal with a black parent and red sibling.
     * @param nodes The mapping of nodes in the tree.
     * @param root The root of the tree.
     * @param parent The parent of the removed node.
     * @param sibling The sibling of the removed node.
     * @return newRoot The new root of the tree.
     */
    function _fixBlackHeightRightNodeBlackParentRedSibling(
        mapping(NodeId => Node) storage nodes,
        NodeId root,
        NodeId parent,
        NodeId sibling
    )
        private
        returns (NodeId newRoot)
    {
        NodeId right = nodes[sibling].right;
        NodeId rightLeft = nodes[right].left;
        assert(right != NULL);
        if (_hasRedChild(nodes, right)) {
            _rotateLeftRight(nodes, parent, sibling, right);
            newRoot = right;

            if (_isRed(nodes, rightLeft)) {
                _setBlack(nodes, rightLeft);
            } else {
                _fixBlackHeightRightNodeRedParent(nodes, root, sibling, nodes[sibling].left);
            }

            _setBlack(nodes, nodes[sibling].right);
        } else {
            _rotateLeft(nodes, parent, sibling);
            newRoot = sibling;

            _setBlack(nodes, sibling);
            _setRed(nodes, nodes[parent].left);
        }

        if (parent != root) {
            return root;
        }
    }

    /**
     * @notice Fixes the black height of the tree after a left node removal with a black parent and red sibling.
     * @param nodes The mapping of nodes in the tree.
     * @param root The root of the tree.
     * @param parent The parent of the removed node.
     * @param sibling The sibling of the removed node.
     * @return newRoot The new root of the tree.
     */
    function _fixBlackHeightLeftNodeBlackParentRedSibling(
        mapping(NodeId => Node) storage nodes,
        NodeId root,
        NodeId parent,
        NodeId sibling
    )
        private
        returns (NodeId newRoot)
    {
        NodeId left = nodes[sibling].left;
        NodeId leftRight = nodes[left].right;
        assert(left != NULL);
        if (_hasRedChild(nodes, left)) {
            _rotateRightLeft(nodes, parent, sibling, left);
            newRoot = left;

            if (_isRed(nodes, leftRight)) {
                _setBlack(nodes, leftRight);
            } else {
                _fixBlackHeightLeftNodeRedParent(nodes, root, sibling, nodes[sibling].right);
            }
        } else {
            _rotateRight(nodes, parent, sibling);
            newRoot = sibling;

            _setBlack(nodes, sibling);
            _setRed(nodes, nodes[parent].right);
        }

        if (parent != root) {
            return root;
        }
    }

    /**
     * @notice Fixes the black height of the tree after a right node removal with a black parent and black sibling.
     * @param nodes The mapping of nodes in the tree.
     * @param root The root of the tree.
     * @param parent The parent of the removed node.
     * @param sibling The sibling of the removed node.
     * @return newRoot The new root of the tree.
     * @return success True if the black height was fixed, false otherwise.
     */
    function _fixBlackHeightRightNodeBlackParentBlackSibling(
        mapping(NodeId => Node) storage nodes,
        NodeId root,
        NodeId parent,
        NodeId sibling
    )
        private
        returns (NodeId newRoot, bool success)
    {
        NodeId left = nodes[sibling].left;
        NodeId right = nodes[sibling].right;

        if (_isRed(nodes, left)) {
            _rotateLeft(nodes, parent, sibling);

            _setBlack(nodes, nodes[sibling].left);

            if (parent == root) {
                return (sibling, true);
            } else {
                return (root, true);
            }
        } else if (_isRed(nodes, right)) {
            _rotateLeftRight(nodes, parent, sibling, right);

            _setBlack(nodes, right);

            if (parent == root) {
                return (right, true);
            } else {
                return (root, true);
            }
        }

        _setRed(nodes, sibling);
        return (root, false);
    }

    /**
     * @notice Fixes the black height of the tree after a left node removal with a black parent and black sibling.
     * @param nodes The mapping of nodes in the tree.
     * @param root The root of the tree.
     * @param parent The parent of the removed node.
     * @param sibling The sibling of the removed node.
     * @return newRoot The new root of the tree.
     * @return success True if the black height was fixed, false otherwise.
     */
    function _fixBlackHeightLeftNodeBlackParentBlackSibling(
        mapping(NodeId => Node) storage nodes,
        NodeId root,
        NodeId parent,
        NodeId sibling
    )
        private
        returns (NodeId newRoot, bool success)
    {
        NodeId left = nodes[sibling].left;
        NodeId right = nodes[sibling].right;

        if (_isRed(nodes, right)) {
            _rotateRight(nodes, parent, sibling);

            _setBlack(nodes, nodes[sibling].right);

            if (parent == root) {
                return (sibling, true);
            } else {
                return (root, true);
            }
        } else if (_isRed(nodes, left)) {
            _rotateRightLeft(nodes, parent, sibling, left);

            _setBlack(nodes, left);

            if (parent == root) {
                return (left, true);
            } else {
                return (root, true);
            }
        }

        _setRed(nodes, sibling);
        return (root, false);
    }

    /**
     * @notice Performs a left rotation on the tree.
     * @param nodes The mapping of nodes in the tree.
     * @param parent The parent of the node to rotate.
     * @param node The node to rotate.
     */
    function _rotateLeft(mapping(NodeId => Node) storage nodes, NodeId parent, NodeId node) private {
        NodeId beta = nodes[node].right;

        uint248 nodeWeight = getWeight(nodes, node);
        uint248 parentWeight = getWeight(nodes, parent);

        _updateChild(nodes, nodes[parent].parent, parent, node);
        _updateChild(nodes, parent, node, beta);
        _updateChild(nodes, node, beta, parent);

        _updateTotalWeight(nodes, parent, parentWeight);
        _updateTotalWeight(nodes, node, nodeWeight);
    }

    /**
     * @notice Performs a left-right rotation on the tree.
     * @param nodes The mapping of nodes in the tree.
     * @param grandfather The grandfather of the node to rotate.
     * @param parent The parent of the node to rotate.
     * @param node The node to rotate.
     */
    function _rotateLeftRight(
        mapping(NodeId => Node) storage nodes,
        NodeId grandfather,
        NodeId parent,
        NodeId node
    )
        private
    {
        NodeId beta = nodes[node].left;
        NodeId gamma = nodes[node].right;

        uint248 nodeWeight = getWeight(nodes, node);
        uint248 parentWeight = getWeight(nodes, parent);
        uint248 grandfatherWeight = getWeight(nodes, grandfather);

        _updateChild(nodes, nodes[grandfather].parent, grandfather, node);
        _updateChild(nodes, grandfather, parent, gamma);
        _updateChild(nodes, parent, node, beta);
        _updateChild(nodes, node, beta, parent);
        _updateChild(nodes, node, gamma, grandfather);

        _updateTotalWeight(nodes, parent, parentWeight);
        _updateTotalWeight(nodes, grandfather, grandfatherWeight);
        _updateTotalWeight(nodes, node, nodeWeight);
    }

    /**
     * @notice Performs a right rotation on the tree.
     * @param nodes The mapping of nodes in the tree.
     * @param parent The parent of the node to rotate.
     * @param node The node to rotate.
     */
    function _rotateRight(mapping(NodeId => Node) storage nodes, NodeId parent, NodeId node) private {
        NodeId beta = nodes[node].left;

        uint248 nodeWeight = getWeight(nodes, node);
        uint248 parentWeight = getWeight(nodes, parent);

        _updateChild(nodes, nodes[parent].parent, parent, node);
        _updateChild(nodes, parent, node, beta);
        _updateChild(nodes, node, beta, parent);

        _updateTotalWeight(nodes, parent, parentWeight);
        _updateTotalWeight(nodes, node, nodeWeight);
    }

    /**
     * @notice Performs a right-left rotation on the tree.
     * @param nodes The mapping of nodes in the tree.
     * @param grandfather The grandfather of the node to rotate.
     * @param parent The parent of the node to rotate.
     * @param node The node to rotate.
     */
    function _rotateRightLeft(
        mapping(NodeId => Node) storage nodes,
        NodeId grandfather,
        NodeId parent,
        NodeId node
    )
        private
    {
        NodeId beta = nodes[node].left;
        NodeId gamma = nodes[node].right;

        uint248 nodeWeight = getWeight(nodes, node);
        uint248 parentWeight = getWeight(nodes, parent);
        uint248 grandfatherWeight = getWeight(nodes, grandfather);

        _updateChild(nodes, nodes[grandfather].parent, grandfather, node);
        _updateChild(nodes, grandfather, parent, beta);
        _updateChild(nodes, parent, node, gamma);
        _updateChild(nodes, node, beta, grandfather);
        _updateChild(nodes, node, gamma, parent);

        _updateTotalWeight(nodes, parent, parentWeight);
        _updateTotalWeight(nodes, grandfather, grandfatherWeight);
        _updateTotalWeight(nodes, node, nodeWeight);
    }

    /**
     * @notice Sets a node to black.
     * @param nodes The mapping of nodes in the tree.
     * @param node The node to set to black.
     */
    function _setBlack(mapping(NodeId => Node) storage nodes, NodeId node) private {
        if (node != NULL) {
            nodes[node].red = false;
        }
    }

    /**
     * @notice Sets a node to red.
     * @param nodes The mapping of nodes in the tree.
     * @param node The node to set to red.
     */
    function _setRed(mapping(NodeId => Node) storage nodes, NodeId node) private {
        assert(node != NULL);
        nodes[node].red = true;
    }

    /**
     * @notice Swaps two nodes in the tree.
     * @param nodes The mapping of nodes in the tree.
     * @param base The base node.
     * @param node The node to swap with the base node.
     */
    /// @dev node has to be a descendant of base
    function _swap(mapping(NodeId => Node) storage nodes, NodeId base, NodeId node) private {
        uint248 nodeWeight = getWeight(nodes, node);
        uint248 baseWeight = getWeight(nodes, base);

        (nodes[node].totalWeight, nodes[base].totalWeight) =
            (nodes[base].totalWeight, nodes[node].totalWeight - nodeWeight + baseWeight);
        for (NodeId current = nodes[node].parent; current != base; current = nodes[current].parent) {
            nodes[current].totalWeight = nodes[current].totalWeight - nodeWeight + baseWeight;
        }

        NodeId nodeParent = nodes[node].parent;
        NodeId nodeLeft = nodes[node].left;
        NodeId nodeRight = nodes[node].right;

        _updateChild(nodes, nodes[base].parent, base, node);
        _updateChild(nodes, node, nodes[node].left, nodes[base].left == node ? base : nodes[base].left);
        _updateChild(nodes, node, nodes[node].right, nodes[base].right == node ? base : nodes[base].right);
        if (nodeParent != base) {
            _updateChild(nodes, nodeParent, node, base);
        }
        _updateChild(nodes, base, nodes[base].left, nodeLeft);
        _updateChild(nodes, base, nodes[base].right, nodeRight);

        (nodes[base].red, nodes[node].red) = (nodes[node].red, nodes[base].red);
    }

    /**
     * @notice Updates a child of a node.
     * @param nodes The mapping of nodes in the tree.
     * @param node The node to update the child of.
     * @param oldChild The old child of the node.
     * @param newChild The new child of the node.
     */
    function _updateChild(
        mapping(NodeId => Node) storage nodes,
        NodeId node,
        NodeId oldChild,
        NodeId newChild
    )
        private
    {
        if (node != NULL) {
            if (nodes[node].left == oldChild) {
                nodes[node].left = newChild;
                nodes[newChild].parent = node;
            } else if (nodes[node].right == oldChild) {
                nodes[node].right = newChild;
                nodes[newChild].parent = node;
            } else {
                revert ChildIsMissing(node, oldChild);
            }
        } else {
            nodes[newChild].parent = NULL;
        }
    }

    /**
     * @notice Updates the total weight of a node.
     * @param nodes The mapping of nodes in the tree.
     * @param node The node to update the total weight of.
     * @param weight The new weight of the node.
     */
    function _updateTotalWeight(mapping(NodeId => Node) storage nodes, NodeId node, uint248 weight) private {
        assert(node != NULL);
        nodes[node].totalWeight =
            weight + _getTotalWeight(nodes, nodes[node].left) + _getTotalWeight(nodes, nodes[node].right);
    }

    /**
     * @notice Gets the total weight of a node.
     * @param nodes The mapping of nodes in the tree.
     * @param node The node to get the total weight of.
     * @return totalWeight The total weight of the node.
     */
    function _getTotalWeight(
        mapping(NodeId => Node) storage nodes,
        NodeId node
    )
        private
        view
        returns (uint248 totalWeight)
    {
        if (node == NULL) {
            return 0;
        }
        return nodes[node].totalWeight;
    }

    /**
     * @notice Gets the grandfather of a node.
     * @param nodes The mapping of nodes in the tree.
     * @param node The node to get the grandfather of.
     * @return grandfather The grandfather of the node.
     */
    function _grandfather(
        mapping(NodeId => Node) storage nodes,
        NodeId node
    )
        private
        view
        returns (NodeId grandfather)
    {
        return _parent(nodes, _parent(nodes, node));
    }

    /**
     * @notice Checks if a node has a red child.
     * @param nodes The mapping of nodes in the tree.
     * @param node The node to check.
     * @return has True if the node has a red child, false otherwise.
     */
    function _hasRedChild(mapping(NodeId => Node) storage nodes, NodeId node) private view returns (bool has) {
        if (node == NULL) {
            return false;
        }
        return _isRed(nodes, nodes[node].left) || _isRed(nodes, nodes[node].right);
    }

    /**
     * @notice Checks if a node is black.
     * @param nodes The mapping of nodes in the tree.
     * @param node The node to check.
     * @return black True if the node is black, false otherwise.
     */
    function _isBlack(mapping(NodeId => Node) storage nodes, NodeId node) private view returns (bool black) {
        return !_isRed(nodes, node);
    }

    /**
     * @notice Checks if a node is red.
     * @param nodes The mapping of nodes in the tree.
     * @param node The node to check.
     * @return red True if the node is red, false otherwise.
     */
    function _isRed(mapping(NodeId => Node) storage nodes, NodeId node) private view returns (bool red) {
        if (node == NULL) {
            return false;
        }
        return nodes[node].red;
    }

    /**
     * @notice Gets the parent of a node.
     * @param nodes The mapping of nodes in the tree.
     * @param node The node to get the parent of.
     * @return parent The parent of the node.
     */
    function _parent(mapping(NodeId => Node) storage nodes, NodeId node) private view returns (NodeId parent) {
        if (node == NULL) {
            return NULL;
        }
        return nodes[node].parent;
    }

    /**
     * @notice Gets the uncle of a node.
     * @param nodes The mapping of nodes in the tree.
     * @param node The node to get the uncle of.
     * @return uncle The uncle of the node.
     */
    function _uncle(mapping(NodeId => Node) storage nodes, NodeId node) private view returns (NodeId uncle) {
        NodeId grandfather = _grandfather(nodes, node);
        if (grandfather == NULL) {
            return NULL;
        }
        if (_parent(nodes, node) == nodes[grandfather].left) {
            return nodes[grandfather].right;
        } else {
            return nodes[grandfather].left;
        }
    }

}

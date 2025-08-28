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
import { NotImplemented } from "../utils/errors.sol";

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

    NodeId constant public NULL = NodeId.wrap(0);

    error InsertNullNode();
    error NotFound();
    error RemoveNullNode();
    error SetWeightOfNullNode();

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
            return newNode;
        }

        NodeId node;
        for(node = root; nodes[node].left != NULL; node = nodes[node].left) {
            nodes[node].totalWeight += weight_;
        }

        nodes[node].totalWeight += weight_;
        _createNode(nodes, newNode, node, weight_);
        nodes[node].left = newNode;

        return _balance(nodes, root, newNode);
    }

    function remove(mapping(NodeId => Node) storage nodes, NodeId id) internal returns (NodeId newRoot) {
        require(id != NULL, RemoveNullNode());
        revert NotImplemented();
    }

    function setWeight(
        mapping(NodeId => Node) storage nodes,
        NodeId node,
        uint256 weight
    )
        internal
        returns (NodeId newRoot)
    {
        require(node != NULL, SetWeightOfNullNode());
        revert NotImplemented();
    }

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
        while (node != RedBlackTree.NULL) {
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

    function findLast(mapping(NodeId => Node) storage nodes, NodeId root) internal returns (NodeId newRoot) {
        revert NotImplemented();
    }

    // Private

    function _balance(mapping(NodeId => Node) storage nodes, NodeId root, NodeId node) private returns (NodeId newRoot) {
        while (node != root) {
            NodeId parent = _parent(nodes, node);
            if (_isBlack(nodes, parent)) {
                return root;
            }
            NodeId uncle = _uncle(nodes, node);
            NodeId grandfather = _grandfather(nodes, node);
            if (_isRed(nodes, uncle)) {
                nodes[parent].red = false;
                nodes[uncle].red = false;
                nodes[grandfather].red = true;
                node = grandfather;
            } else {
                NodeId localRoot;
                if (parent == nodes[grandfather].left) {
                    if (node == nodes[parent].left) {
                        localRoot = _balanceLeftLeft(nodes, node, parent, uncle, grandfather);
                    } else {
                        localRoot = _balanceLeftRight(nodes, node, parent, uncle, grandfather);
                    }
                } else {
                    if (node == nodes[parent].right) {
                        localRoot = _balanceRightRight(nodes, node, parent, uncle, grandfather);
                    } else {
                        localRoot = _balanceRightLeft(nodes, node, parent, uncle, grandfather);
                    }
                }
                if (grandfather == root) {
                    return localRoot;
                } else {
                    NodeId grandGrandfather = _parent(nodes, grandfather);
                    if (grandfather == nodes[grandGrandfather].left) {
                        nodes[grandGrandfather].left = localRoot;
                    } else {
                        nodes[grandGrandfather].right = localRoot;
                    }
                    return root;
                }
            }
        }
        if (_isRed(nodes, node)) {
            nodes[node].red = false;
        }
        return node;
    }

    function _balanceRightRight(
        mapping(NodeId => Node) storage nodes,
        NodeId node,
        NodeId parent,
        NodeId uncle,
        NodeId grandfather
    )
        private
        returns (NodeId newGrandfather)
    {
        NodeId alpha = uncle;
        NodeId beta = nodes[parent].left;

        uint248 nodeWeight = _getWeight(nodes, node);
        uint248 parentWeight = _getWeight(nodes, parent);
        uint248 grandfatherWeight = _getWeight(nodes, grandfather);

        nodes[parent].parent = nodes[grandfather].parent;
        nodes[parent].left = grandfather;

        nodes[grandfather].parent = parent;
        nodes[grandfather].left = alpha;
        nodes[grandfather].right = beta;

        _setParentIfNodeExists(nodes, alpha, grandfather);
        _setParentIfNodeExists(nodes, beta, grandfather);

        nodes[parent].red = false;
        nodes[grandfather].red = true;

        nodes[grandfather].totalWeight = grandfatherWeight + _getTotalWeight(nodes, alpha) + _getTotalWeight(nodes, beta);
        nodes[parent].totalWeight = parentWeight + nodes[grandfather].totalWeight + nodeWeight;

        return parent;
    }

    function _balanceLeftLeft(
        mapping(NodeId => Node) storage nodes,
        NodeId node,
        NodeId parent,
        NodeId uncle,
        NodeId grandfather
    )
        private
        returns (NodeId newGrandfather)
    {
        NodeId gamma = uncle;
        NodeId delta = nodes[grandfather].right;

        uint248 nodeWeight = _getWeight(nodes, node);
        uint248 parentWeight = _getWeight(nodes, parent);
        uint248 grandfatherWeight = _getWeight(nodes, grandfather);

        nodes[parent].parent = nodes[grandfather].parent;
        nodes[parent].right = grandfather;

        nodes[grandfather].parent = parent;
        nodes[grandfather].left = gamma;
        nodes[grandfather].right = delta;

        _setParentIfNodeExists(nodes, gamma, grandfather);
        _setParentIfNodeExists(nodes, delta, grandfather);

        nodes[parent].red = false;
        nodes[grandfather].red = true;

        nodes[grandfather].totalWeight = grandfatherWeight + _getTotalWeight(nodes, gamma) + _getTotalWeight(nodes, delta);
        nodes[parent].totalWeight = parentWeight + nodes[grandfather].totalWeight + nodeWeight;

        return parent;
    }

    function _balanceRightLeft(
        mapping(NodeId => Node) storage nodes,
        NodeId node,
        NodeId parent,
        NodeId uncle,
        NodeId grandfather
    )
        private
        returns (NodeId newGrandfather)
    {
        NodeId alpha = uncle;
        NodeId beta = nodes[node].left;
        NodeId gamma = nodes[node].right;
        NodeId delta = nodes[parent].right;

        uint248 nodeWeight = _getWeight(nodes, node);
        uint248 parentWeight = _getWeight(nodes, parent);
        uint248 grandfatherWeight = _getWeight(nodes, grandfather);

        nodes[node].parent = nodes[grandfather].parent;
        nodes[node].left = grandfather;
        nodes[node].right = parent;

        nodes[parent].parent = node;
        nodes[parent].left = gamma;

        nodes[grandfather].parent = node;
        nodes[grandfather].right = beta;

        _setParentIfNodeExists(nodes, beta, grandfather);
        _setParentIfNodeExists(nodes, gamma, parent);

        nodes[node].red = false;
        nodes[grandfather].red = true;

        nodes[grandfather].totalWeight = grandfatherWeight + _getTotalWeight(nodes, alpha) + _getTotalWeight(nodes, beta);
        nodes[parent].totalWeight = parentWeight + _getTotalWeight(nodes, gamma) + _getTotalWeight(nodes, delta);
        nodes[node].totalWeight = nodeWeight + nodes[parent].totalWeight + nodes[grandfather].totalWeight;

        return node;
    }

    function _balanceLeftRight(
        mapping(NodeId => Node) storage nodes,
        NodeId node,
        NodeId parent,
        NodeId uncle,
        NodeId grandfather
    )
        private
        returns (NodeId newGrandfather)
    {
        NodeId alpha = nodes[parent].left;
        NodeId beta = nodes[node].left;
        NodeId gamma = nodes[node].right;
        NodeId delta = nodes[grandfather].right;

        uint248 nodeWeight = _getWeight(nodes, node);
        uint248 parentWeight = _getWeight(nodes, parent);
        uint248 grandfatherWeight = _getWeight(nodes, grandfather);

        nodes[node].parent = nodes[grandfather].parent;
        nodes[node].left = parent;
        nodes[node].right = grandfather;

        nodes[parent].parent = node;
        nodes[parent].right = beta;

        nodes[grandfather].parent = node;
        nodes[grandfather].left = gamma;

        _setParentIfNodeExists(nodes, beta, grandfather);
        _setParentIfNodeExists(nodes, gamma, parent);

        nodes[node].red = false;
        nodes[grandfather].red = true;

        nodes[grandfather].totalWeight = grandfatherWeight + _getTotalWeight(nodes, gamma) + _getTotalWeight(nodes, delta);
        nodes[parent].totalWeight = parentWeight + _getTotalWeight(nodes, alpha) + _getTotalWeight(nodes, beta);
        nodes[node].totalWeight = nodeWeight + nodes[parent].totalWeight + nodes[grandfather].totalWeight;

        return node;
    }

    function _createNode(mapping(NodeId => Node) storage nodes, NodeId id, NodeId parent, uint248 weight) private {
        nodes[id] = Node({
            id: id,
            parent: parent,
            left: NULL,
            right: NULL,
            totalWeight: weight,
            red: true
        });
    }

    function _setParentIfNodeExists(mapping(NodeId => Node) storage nodes, NodeId node, NodeId newParent) private {
        if (node != NULL) {
            nodes[node].parent = newParent;
        }
    }

    function _getTotalWeight(mapping(NodeId => Node) storage nodes, NodeId node) private view returns (uint248 totalWeight) {
        if (node == NULL) {
            return 0;
        }
        return nodes[node].totalWeight;
    }

    function _getWeight(mapping(NodeId => Node) storage nodes, NodeId node) private view returns (uint248 weight) {
        if (node == NULL) {
            return 0;
        }
        weight = nodes[node].totalWeight;
        if (nodes[node].left != NULL) {
            weight -= nodes[nodes[node].left].totalWeight;
        }
        if (nodes[node].right != NULL) {
            weight -= nodes[nodes[node].right].totalWeight;
        }
    }

    function _grandfather(mapping(NodeId => Node) storage nodes, NodeId node) private view returns (NodeId grandfather) {
        return _parent(nodes, _parent(nodes, node));
    }

    function _isBlack(mapping(NodeId => Node) storage nodes, NodeId node) private view returns (bool black) {
        return !_isRed(nodes, node);
    }

    function _isRed(mapping(NodeId => Node) storage nodes, NodeId node) private view returns (bool red) {
        if (node == NULL) {
            return false;
        }
        return nodes[node].red;
    }

    function _parent(mapping(NodeId => Node) storage nodes, NodeId node) private view returns (NodeId parent) {
        if (node == NULL) {
            return NULL;
        }
        return nodes[node].parent;
    }

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

    function getBiggestChild(
        mapping(NodeId => Node) storage nodes,
        NodeId vertex
    )
        private
        view
        returns (NodeId biggestChild)
    {
        biggestChild = vertex;
        while (nodes[biggestChild].right != NULL) {
            biggestChild = nodes[biggestChild].right;
        }
    }

    function hasLeft(mapping(NodeId => Node) storage nodes, NodeId vertex) private view returns (bool exists) {
        return nodes[vertex].left != NULL;
    }

    function hasRight(mapping(NodeId => Node) storage nodes, NodeId vertex) private view returns (bool exists) {
        return nodes[vertex].right != NULL;
    }
}

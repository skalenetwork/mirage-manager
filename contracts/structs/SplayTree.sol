// SPDX-License-Identifier: AGPL-3.0-only

/*
    Random.sol - mirage-manager
    Copyright (C) 2025-Present SKALE Labs
    @author Dmytro Stebaiev

    mirage-manager is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published
    by the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    mirage-manager is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with mirage-manager.  If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity ^0.8.24;

import { NodeId } from "@skalenetwork/professional-interfaces/INodes.sol";


library SplayTree {
    struct Node {
        NodeId id;
        NodeId parent;
        NodeId left;
        NodeId right;
        uint256 totalWeight;
    }

    NodeId constant public NULL = NodeId.wrap(0);

    error InsertNullNode();
    error NotFound();
    error RemoveNullNode();
    error SetWeightOfNullNode();
    error SplayOnNull();

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
        uint256 totalWeight = weight;
        if (root != NULL) {
            totalWeight += nodes[root].totalWeight;
        }
        _createNode(nodes, newNode, totalWeight);
        nodes[newNode].right = root;
        if (root != NULL) {
            nodes[root].parent = newNode;
        }
        return newNode;
    }

    function remove(mapping(NodeId => Node) storage nodes, NodeId id) internal returns (NodeId newRoot) {
        require(id != NULL, RemoveNullNode());
        splay(nodes, id);
        if (hasLeft(nodes, id)) {
            NodeId left = nodes[id].left;
            NodeId right = nodes[id].right;
            nodes[left].parent = NULL;
            NodeId biggestChild = getBiggestChild(nodes, left);
            splay(nodes, biggestChild);
            nodes[biggestChild].right = right;
            nodes[right].parent = biggestChild;
            nodes[biggestChild].totalWeight += nodes[right].totalWeight;
            newRoot = biggestChild;
        } else {
            if (hasRight(nodes, id)) {
                newRoot = nodes[id].right;
                nodes[newRoot].parent = NULL;
            } else {
                newRoot = NULL;
            }
        }
        delete nodes[id];
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
        splay(nodes, node);
        NodeId left = nodes[node].left;
        NodeId right = nodes[node].right;
        nodes[node].totalWeight = weight + nodes[left].totalWeight + nodes[right].totalWeight;
        return node;
    }

    function findByWeight(
        mapping(NodeId => Node) storage nodes,
        NodeId root,
        uint256 weight
    )
        internal
        returns (NodeId newRoot)
    {
        NodeId node = root;
        while (node != SplayTree.NULL) {
            NodeId left = nodes[node].left;
            if (weight < nodes[left].totalWeight) {
                node = left;
            } else {
                NodeId right = nodes[node].right;
                uint256 leftAndNodeWeight = nodes[node].totalWeight - nodes[right].totalWeight;
                if (weight < leftAndNodeWeight) {
                    return splay(nodes, node);
                } else {
                    weight -= leftAndNodeWeight;
                    node = right;
                }
            }
        }
        revert NotFound();
    }

    function splay(mapping(NodeId => Node) storage nodes, NodeId id) internal returns (NodeId newRoot) {
        require(id != NULL, SplayOnNull());
        if (nodes[id].parent != NULL) {
            _splay(nodes, nodes[id]);
        }
        return id;
    }

    // Private

    function _createNode(mapping(NodeId => Node) storage nodes, NodeId id, uint256 weight) internal {
        nodes[id] = Node({
            id: id,
            parent: NULL,
            left: NULL,
            right: NULL,
            totalWeight: weight
        });
    }

    function _splay(mapping(NodeId => Node) storage nodes, Node memory node) private {
        while (node.parent != NULL) {
            NodeId parent = node.parent;
            if (nodes[parent].parent == NULL) {
                if (node.id == nodes[parent].left) {
                    _leftZig(nodes, node, parent);
                } else {
                    _rightZig(nodes, node, parent);
                }
            } else {
                NodeId grandParent = nodes[parent].parent;
                if (node.id == nodes[parent].left) {
                    if (parent == nodes[grandParent].left) {
                        _leftZigZig(nodes, node, parent, grandParent);
                    } else {
                        _leftZigZag(nodes, node, parent, grandParent);
                    }
                } else {
                    if (parent == nodes[grandParent].left) {
                        _rightZigZag(nodes, node, parent, grandParent);
                    } else {
                        _rightZigZig(nodes, node, parent, grandParent);
                    }
                }
            }
        }
        nodes[node.id] = node;
    }

    function _leftZig(mapping(NodeId => Node) storage nodes, Node memory node, NodeId parent) private {
        NodeId beta = node.right;
        uint256 parentAndGammaWeight = nodes[parent].totalWeight - node.totalWeight;

        node.parent = NULL;
        node.right = parent;
        node.totalWeight = nodes[parent].totalWeight;

        nodes[parent].parent = node.id;
        nodes[parent].left = beta;
        nodes[parent].totalWeight = parentAndGammaWeight + nodes[beta].totalWeight;

        nodes[beta].parent = parent;
    }

    function _rightZig(mapping(NodeId => Node) storage nodes, Node memory node, NodeId parent) private {
        NodeId beta = node.left;
        uint256 parentAndAlphaWeight = nodes[parent].totalWeight - node.totalWeight;

        node.parent = NULL;
        node.left = parent;
        node.totalWeight = nodes[parent].totalWeight;

        nodes[parent].parent = node.id;
        nodes[parent].right = beta;
        nodes[parent].totalWeight = parentAndAlphaWeight + nodes[beta].totalWeight;

        nodes[beta].parent = parent;
    }

    function _leftZigZig(
        mapping(NodeId => Node) storage nodes,
        Node memory node,
        NodeId parent,
        NodeId grandParent
    )
        private
    {
        NodeId beta = node.right;
        NodeId gamma = nodes[parent].right;
        uint256 parentAndGammaWeight = nodes[parent].totalWeight - node.totalWeight;
        uint256 grandParentAndDeltaWeight = nodes[grandParent].totalWeight - nodes[parent].totalWeight;

        node.parent = nodes[grandParent].parent;
        if (node.parent != NULL) {
            if (nodes[node.parent].left == grandParent) {
                nodes[node.parent].left = node.id;
            } else {
                nodes[node.parent].right = node.id;
            }
        }
        node.right = parent;
        node.totalWeight = nodes[grandParent].totalWeight;

        nodes[parent].parent = node.id;
        nodes[parent].left = beta;
        nodes[parent].right = grandParent;
        nodes[parent].totalWeight = parentAndGammaWeight + grandParentAndDeltaWeight + nodes[beta].totalWeight;

        nodes[grandParent].parent = parent;
        nodes[grandParent].left = gamma;
        nodes[grandParent].totalWeight = grandParentAndDeltaWeight + nodes[gamma].totalWeight;

        nodes[beta].parent = parent;
        nodes[gamma].parent = grandParent;
    }

    function _rightZigZig(
        mapping(NodeId => Node) storage nodes,
        Node memory node,
        NodeId parent,
        NodeId grandParent
    )
        private
    {
        NodeId beta = nodes[parent].left;
        NodeId gamma = node.left;
        uint256 parentAndBetaWeight = nodes[parent].totalWeight - node.totalWeight;
        uint256 grandParentAndAlphaWeight = nodes[grandParent].totalWeight - nodes[parent].totalWeight;

        node.parent = nodes[grandParent].parent;
        if (node.parent != NULL) {
            if (nodes[node.parent].left == grandParent) {
                nodes[node.parent].left = node.id;
            } else {
                nodes[node.parent].right = node.id;
            }
        }
        node.left = parent;
        node.totalWeight = nodes[grandParent].totalWeight;

        nodes[parent].parent = node.id;
        nodes[parent].right = gamma;
        nodes[parent].left = grandParent;
        nodes[parent].totalWeight = parentAndBetaWeight + grandParentAndAlphaWeight + nodes[gamma].totalWeight;

        nodes[grandParent].parent = parent;
        nodes[grandParent].right = beta;
        nodes[grandParent].totalWeight = grandParentAndAlphaWeight + nodes[beta].totalWeight;

        nodes[beta].parent = grandParent;
        nodes[gamma].parent = parent;
    }

    function _leftZigZag(
        mapping(NodeId => Node) storage nodes,
        Node memory node,
        NodeId parent,
        NodeId grandParent
    )
        private
    {
        NodeId beta = node.left;
        NodeId gamma = node.right;
        uint256 parentAndDeltaWeight = nodes[parent].totalWeight - node.totalWeight;
        uint256 grandParentAndAlphaWeight = nodes[grandParent].totalWeight - nodes[parent].totalWeight;

        node.parent = nodes[grandParent].parent;
        if (node.parent != NULL) {
            if (nodes[node.parent].left == grandParent) {
                nodes[node.parent].left = node.id;
            } else {
                nodes[node.parent].right = node.id;
            }
        }
        node.left = grandParent;
        node.right = parent;
        node.totalWeight = nodes[grandParent].totalWeight;

        nodes[parent].parent = node.id;
        nodes[parent].left = gamma;
        nodes[parent].totalWeight = parentAndDeltaWeight + nodes[gamma].totalWeight;

        nodes[grandParent].parent = node.id;
        nodes[grandParent].right = beta;
        nodes[grandParent].totalWeight = grandParentAndAlphaWeight + nodes[beta].totalWeight;

        nodes[beta].parent = grandParent;
        nodes[gamma].parent = parent;
    }

    function _rightZigZag(
        mapping(NodeId => Node) storage nodes,
        Node memory node,
        NodeId parent,
        NodeId grandParent
    )
        private
    {
        NodeId beta = node.left;
        NodeId gamma = node.right;
        uint256 parentAndAlphaWeight = nodes[parent].totalWeight - node.totalWeight;
        uint256 grandParentAndDeltaWeight = nodes[grandParent].totalWeight - nodes[parent].totalWeight;

        node.parent = nodes[grandParent].parent;
        if (node.parent != NULL) {
            if (nodes[node.parent].left == grandParent) {
                nodes[node.parent].left = node.id;
            } else {
                nodes[node.parent].right = node.id;
            }
        }
        node.left = parent;
        node.right = grandParent;
        node.totalWeight = nodes[grandParent].totalWeight;

        nodes[parent].parent = node.id;
        nodes[parent].right = beta;
        nodes[parent].totalWeight = parentAndAlphaWeight + nodes[beta].totalWeight;

        nodes[grandParent].parent = node.id;
        nodes[grandParent].left = gamma;
        nodes[grandParent].totalWeight = grandParentAndDeltaWeight + nodes[gamma].totalWeight;

        nodes[beta].parent = parent;
        nodes[gamma].parent = grandParent;
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

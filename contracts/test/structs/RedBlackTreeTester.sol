// SPDX-License-Identifier: AGPL-3.0-only

/*
    RedBlackTreeTester.sol - fair-manager
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

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {NodeId} from "@skalenetwork/fair-manager-interfaces/INodes.sol";
import {RedBlackTree} from "../../structs/RedBlackTree.sol";

interface IRedBlackTreeTester {
    function insertSmallest(NodeId node, uint256 weight) external;
    function remove(NodeId node) external;
    function setWeight(
        NodeId node,
        uint256 weight
    ) external;
    function getNodes() external view returns (NodeId[] memory nodes);
    function validate() external view returns(bool result);
    function getNumNodes() external view returns (uint256 numNodes);

}


contract RedBlackTreeTester is IRedBlackTreeTester{
    using RedBlackTree for mapping(NodeId => RedBlackTree.Node);
    using Strings for uint256;

    NodeId public constant NULL = RedBlackTree.NULL;
    NodeId public constant EMPTY = NodeId.wrap(type(uint256).max);
    mapping(NodeId node => RedBlackTree.Node data) public tree;
    mapping(NodeId node => uint256 weight) public weights;
    NodeId public root;

    error IncorrectBlackHeight(NodeId node, uint256 leftBlackHeight, uint256 rightBlackHeight);
    error IncorrectParentOfLeftChild(NodeId parent, NodeId child, NodeId actualParent);
    error IncorrectParentOfRightChild(NodeId parent, NodeId child, NodeId actualParent);
    error RedNodeHasRedLeftChild(NodeId node, NodeId redChild);
    error RedNodeHasRedRightChild(NodeId node, NodeId redChild);
    error RootHasParent(NodeId root, NodeId parent);
    error RootIsNotBlack(NodeId root);
    error TotalWeightIsIncorrect(NodeId node, uint256 expected, uint256 actual);

    function insertSmallest(NodeId node, uint256 weight) external override {
        root = tree.insertSmallest(root, node, weight);
        weights[node] = weight;
    }

    function remove(NodeId node) external override {
        root = tree.remove(root, node);
    }

    function setWeight(
        NodeId node,
        uint256 weight
    ) external override {
        weights[node] = weight;
        tree.setWeight(node, weight);
    }

    function validate() external view override returns(bool result) {
        if (root == NULL) {
            return true;
        }
        require(_isBlack(root), RootIsNotBlack(root));
        require(tree[root].parent == NULL, RootHasParent(root, tree[root].parent));
        _validate(root);
        return true;
    }

    function getNodes() external view override returns (NodeId[] memory nodes) {
        nodes = new NodeId[](_count(root));
        _getNodes(root, nodes, 0);
    }

    function getNumNodes() external view override returns (uint256 numNodes) {
        return _count(root);
    }

    // private

    function _isBlack(NodeId node) private view returns (bool black) {
        return !_isRed(node);
    }

    function _isRed(NodeId node) private view returns (bool red) {
        if (node == NULL) {
            return false;
        }
        return tree[node].red;
    }

    function _getNodes(NodeId node, NodeId[] memory nodes, uint256 index) private view returns (uint256 newIndex){
        if (node == NULL) {
            return index;
        }
        index = _getNodes(tree[node].left, nodes, index);
        nodes[index] = node;
        ++index;
        index = _getNodes(tree[node].right, nodes, index);
        return index;
    }

    function _count(NodeId node) private view returns (uint256 value) {
        if (node == NULL) {
            return 0;
        } else {
            return 1 + _count(tree[node].left) + _count(tree[node].right);
        }
    }

    function _validate(NodeId currentRoot) private view returns (uint256 blackHeight, uint256 weight) {
        if (currentRoot == NULL) {
            return (1, 0);
        }
        NodeId left = tree[currentRoot].left;
        NodeId right = tree[currentRoot].right;

        if (left != NULL) {
            require(
                tree[left].parent == currentRoot,
                IncorrectParentOfLeftChild(currentRoot, left, tree[left].parent)
            );
        }
        if (right != NULL) {
            require(
                tree[right].parent == currentRoot,
                IncorrectParentOfRightChild(currentRoot, right, tree[right].parent)
            );
        }

        if (_isRed(currentRoot)) {
            require(_isBlack(left), RedNodeHasRedLeftChild(currentRoot, left));
            require(_isBlack(right), RedNodeHasRedRightChild(currentRoot, right));
        }

        (uint256 leftBlackHeight, uint256 leftWeight) = _validate(left);
        (uint256 rightBlackHeight, uint256 rightWeight) = _validate(right);
        require(
            leftBlackHeight == rightBlackHeight,
            IncorrectBlackHeight(currentRoot, leftBlackHeight, rightBlackHeight)
        );
        require(
            leftWeight + rightWeight + weights[currentRoot] == tree[currentRoot].totalWeight,
            TotalWeightIsIncorrect(
                currentRoot,
                leftWeight + rightWeight + weights[currentRoot],
                tree[currentRoot].totalWeight
            )
        );

        blackHeight = leftBlackHeight;
        if (_isBlack(currentRoot)) {
            ++blackHeight;
        }
        weight = tree[currentRoot].totalWeight;
    }
}

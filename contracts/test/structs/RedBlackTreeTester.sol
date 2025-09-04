// SPDX-License-Identifier: AGPL-3.0-only

/*
    SplayTreeTester.sol - fair-manager
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

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {NodeId} from "@skalenetwork/fair-manager-interfaces/INodes.sol";
// for debugging purposes only
// solhint-disable-next-line no-console
import {console} from "hardhat/console.sol";
import {RedBlackTree} from "../../structs/RedBlackTree.sol";

interface IRedBlackTreeTester {
    function insertSmallest(NodeId node, uint256 weight) external;
    function remove(NodeId node) external;
    function getNodes() external view returns (NodeId[] memory nodes);
    function print() external view;
    function validate() external view;
}


contract RedBlackTreeTester is IRedBlackTreeTester{
    using RedBlackTree for mapping(NodeId => RedBlackTree.Node);
    using Strings for uint256;

    mapping(NodeId node => RedBlackTree.Node data) public tree;
    mapping(NodeId node => uint256 weight) public weights;
    NodeId public root;
    NodeId public constant NULL = RedBlackTree.NULL;
    NodeId public constant EMPTY = NodeId.wrap(type(uint256).max);

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

    function validate() external view override {
        if (root == NULL) {
            return;
        }
        require(_isBlack(root), RootIsNotBlack(root));
        require(tree[root].parent == NULL, RootHasParent(root, tree[root].parent));
        _validate(root);
    }

    function getNodes() external view override returns (NodeId[] memory nodes) {
        return _getNodes(root);
    }

    function print() external view override {
        // it's for debugging purposes only
        // solhint-disable-next-line no-console
        console.log("Tree:");
        uint256 height = _height(root);
        for (uint256 level = height; level + 1 > 1; --level) {
            _print(level);
        }
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

    function _getNodes(NodeId node) private view returns (NodeId[] memory nodes) {
        if (node == NULL) {
            return new NodeId[](0);
        }
        NodeId[] memory leftNodes = _getNodes(tree[node].left);
        NodeId[] memory rightNodes = _getNodes(tree[node].right);
        uint256 leftNodesLength = leftNodes.length;
        uint256 rightNodesLength = rightNodes.length;
        nodes = new NodeId[](leftNodes.length + 1 + rightNodes.length);
        uint256 index = 0;
        for (uint256 i = 0; i < leftNodesLength; ++i) {
            nodes[index] = leftNodes[i];
            ++index;
        }
        nodes[index] = node;
        ++index;
        for (uint256 i = 0; i < rightNodesLength; ++i) {
            nodes[index] = rightNodes[i];
            ++index;
        }
    }

    function _height(NodeId node) private view returns (uint256 value) {
        if (node == NULL) {
            return 1;
        }
        else return 1 + Math.max(_height(tree[node].left), _height(tree[node].right));
    }

    function _getNodesWithHeight(
        NodeId node,
        uint256 height,
        uint256 targetHeight
    )
        private
        view
        returns (NodeId[] memory nodes)
    {
        assert(height + 1 > targetHeight);
        if (height > targetHeight) {
            NodeId[] memory left;
            NodeId[] memory right;
            if (node == NULL || node == EMPTY) {
                left = _getNodesWithHeight(EMPTY, height - 1, targetHeight);
                right = _getNodesWithHeight(EMPTY, height - 1, targetHeight);
            } else {
                left = _getNodesWithHeight(tree[node].left, height - 1, targetHeight);
                right = _getNodesWithHeight(tree[node].right, height - 1, targetHeight);
            }
            uint256 leftLength = left.length;
            uint256 rightLength = right.length;
            nodes = new NodeId[](leftLength + rightLength);
            uint256 index = 0;
            for (uint256 i = 0; i < leftLength; ++i) {
                nodes[index] = left[i];
                ++index;
            }
            for (uint256 i = 0; i < rightLength; ++i) {
                nodes[index] = right[i];
                ++index;
            }
            return nodes;
        }
        nodes = new NodeId[](1);
        nodes[0] = node;
    }

    function _print(uint256 height) private view {
        NodeId[] memory nodes = _getNodesWithHeight(root, _height(root), height);
        uint256 nodesNumber = nodes.length;
        string memory line = "";
        string memory offset = _offset(_width(height - 1));
        for (uint256 i = 0; i < nodesNumber; ++i) {
            string memory node = NodeId.unwrap(nodes[i]).toString();
            if (nodes[i] == NULL) {
                node = "x";
            }
            if (nodes[i] == EMPTY) {
                node = " ";
            }
            if (_isRed(nodes[i])) {
                node = string.concat(node, "!");
            }
            string memory rightOffset;
            if (bytes(offset).length + 1 > bytes(node).length) {
                rightOffset = _offset(bytes(offset).length + 1 - bytes(node).length);
            } else {
                rightOffset = " ";
            }
            string memory output = string.concat(offset, node, rightOffset);
            line = string.concat(line, " ", output);
        }
        // it's for debugging purposes only
        // solhint-disable-next-line no-console
        console.log(line);
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

    function _offset(uint256 width) private pure returns (string memory result) {
        result = "";
        for (uint256 i = 0; i < width; ++i) {
            result = string.concat(result, " ");
        }
    }

    function _width(uint256 height) private pure returns (uint256 value) {
        if (height == 0) {
            return 0;
        }
        if (height == 1) {
            return 1;
        }
        return 1 + 2 * _width(height - 1);
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
// cspell:words: IRBT
/*
    RBTHandler.sol - fair-manager
    Copyright (C) 2025-Present SKALE Labs
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

import {RedBlackTreeTester, NodeId} from "../../contracts/test/structs/RedBlackTreeTester.sol";

import {Test} from "../../lib/forge-std/src/Test.sol";

/**
 * @title IRBTHandler
 * @author Eduardo Vasques
 * @notice Interface of the Red-Black Tree Tester handler
 */
interface IRBTHandler {
    /**
     * @notice Inserts a node with a given weight into the Red-Black Tree
     * @param nodeIndex Index of node in the fixture node array
     * @param weight The weight to associate with the node (must be greater than 0)
     */
    function insert(uint8 nodeIndex, uint48 weight) external;

    /**
     * @notice Removes a node from the Red-Black Tree
     * @param nodeIndex Index of node in the fixture node array
     */
    function remove(uint8 nodeIndex) external;

    /**
     * @notice Updates the weight of an existing node in the Red-Black Tree
     * @param nodeIndex Index of node in the fixture node array
     * @param weight The new weight for the node (must be greater than 0)
     */
    function setWeight(uint8 nodeIndex, uint48 weight) external;

    /**
     * @notice Checks if a node has been inserted into the tree
     * @param node The NodeId to check
     * @return inserted True if the node is in the tree, false otherwise
     */
    function insertedKeys(NodeId node) external view returns (bool inserted);

    /**
     * @notice Gets a key from the key list by index
     * @param index The index in the key list
     * @return nodeId The NodeId at the specified index
     */
    function keyList(uint256 index) external view returns (NodeId nodeId);

    /**
     * @notice Gets a fixture node by index
     * @param index The index of the node in the fixture array
     * @return nodeId The NodeId at the specified index
     */
    function fixtureNode(uint256 index) external view returns (NodeId nodeId);
}

/**
 * @title RBT Handler
 * @author Eduardo Vasques
 * @notice Handler contract for the Red-Black Tree Test contract
 */
contract RBTHandler is Test, IRBTHandler {

    /// @notice The Red-Black Tree tester contract instance
    RedBlackTreeTester public rbt;

    /// @inheritdoc IRBTHandler
    mapping(NodeId node => bool inserted) public insertedKeys;

    /// @inheritdoc IRBTHandler
    NodeId[] public keyList;

    /// @inheritdoc IRBTHandler
    NodeId[] public fixtureNode;

    /**
     * @notice Constructor
     * @param _rbt The address of the RedBlackTreeTester contract
     * @dev Max is set to 150 nodes in the tree - corresponds to a Max tree height of 8
     * @dev If increased beyond 256 nodes, adjust nodeIndex inputs to allow indexes over 255
     */
    constructor(RedBlackTreeTester _rbt) {
        rbt = _rbt;
        for(uint256 i = 1; i < 151; ++i){
            fixtureNode.push(NodeId.wrap(i));
        }
    }

    /// @inheritdoc IRBTHandler
    function insert(uint8 nodeIndex, uint48 weight) public override {
        NodeId node = fixtureNode[nodeIndex % fixtureNode.length];
        vm.assume(!insertedKeys[NodeId.wrap(NodeId.unwrap(node) - 1)]);
        vm.assume(weight > 0);
        _insert(node, weight);
    }

    /// @inheritdoc IRBTHandler
    function remove(uint8 nodeIndex) public override {
        NodeId node = fixtureNode[nodeIndex % fixtureNode.length];
        vm.assume(insertedKeys[NodeId.wrap(NodeId.unwrap(node) - 1)]);
        _remove(node);
    }

    /// @inheritdoc IRBTHandler
    function setWeight(uint8 nodeIndex, uint48 weight) public override {
        NodeId node = fixtureNode[nodeIndex % fixtureNode.length];
        vm.assume(insertedKeys[NodeId.wrap(NodeId.unwrap(node) - 1)]);
        vm.assume(weight > 0);

        rbt.setWeight(node, weight);
    }

    /**
     * @notice Internal helper to insert a node into the tree
     * @param node The NodeId to insert
     * @param weight The weight to associate with the node
     */
    function _insert(NodeId node, uint256 weight) private {
        rbt.insertSmallest(node, weight);
        insertedKeys[NodeId.wrap(NodeId.unwrap(node) - 1)] = true;
        keyList.push(node);
    }

    /**
     * @notice Internal helper to remove a node from the tree
     * @param node The NodeId to remove
     */
    function _remove(NodeId node) private {
        rbt.remove(node);

        insertedKeys[NodeId.wrap(NodeId.unwrap(node) - 1)] = false;
        if (NodeId.unwrap(node) - 1 < keyList.length - 1) {
            keyList[NodeId.unwrap(node) - 1] = keyList[keyList.length - 1];
        }
        keyList.pop();
    }
}

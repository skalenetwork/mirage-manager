// SPDX-License-Identifier: AGPL-3.0-only

/*
    RBTHandler.sol - fair-manager
    Copyright (C) 2025-Present SKALE Labs


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

import {Test} from "forge-std/Test.sol";
import {RedBlackTreeTester, NodeId} from "../../contracts/test/structs/RedBlackTreeTester.sol";


contract RBTHandler is Test {
    RedBlackTreeTester rbt;
    mapping(NodeId => bool) public insertedKeys;
    NodeId[] public keyList;

    NodeId[] public fixtureNode;

    constructor(RedBlackTreeTester _rbt) {
        rbt = _rbt;

        // 150 nodes corresponds to a tree height of 8
        for(uint256 i = 1; i <= 150; ++i){
            fixtureNode.push(NodeId.wrap(i));
        }
    }

    function insert(uint8 nodeIndex, uint48 weight) public {
        NodeId node = fixtureNode[nodeIndex % fixtureNode.length];
        vm.assume(!insertedKeys[NodeId.wrap(NodeId.unwrap(node) - 1)]);
        vm.assume(weight > 0);
        _insert(node, weight);
    }

    function remove(uint8 nodeIndex) external {
        NodeId node = fixtureNode[nodeIndex % fixtureNode.length];
        vm.assume(insertedKeys[NodeId.wrap(NodeId.unwrap(node) - 1)]);
        _remove(node);
    }

    function setWeight(uint8 nodeIndex, uint48 weight) external {
        NodeId node = fixtureNode[nodeIndex % fixtureNode.length];
        vm.assume(insertedKeys[NodeId.wrap(NodeId.unwrap(node) - 1)]);
        vm.assume(weight > 0);

        rbt.setWeight(node, weight);
    }

    function _insert(NodeId node, uint256 weight) private {
        rbt.insertSmallest(node, weight);
        insertedKeys[NodeId.wrap(NodeId.unwrap(node) - 1)] = true;
        keyList.push(node);
    }

    function _remove(NodeId node) private {
        rbt.remove(node);

        insertedKeys[NodeId.wrap(NodeId.unwrap(node) - 1)] = false;
        if (NodeId.unwrap(node) - 1 < keyList.length - 1) {
            keyList[NodeId.unwrap(node) - 1] = keyList[keyList.length - 1];
        }
        keyList.pop();
    }
}
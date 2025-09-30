
// SPDX-License-Identifier: AGPL-3.0-only

/*
    RedBlackTreeFuzzy.t.sol - fair-manager
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

// 1. Import Foundry's standard test library
import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

import {RedBlackTreeTesterV2, NodeId} from "../contracts/test/structs/RedBlackTreeTesterV2.sol";

// 3. Your test contract must inherit from `Test`

// This is your Handler contract
contract RBTHandler is Test {
    RedBlackTreeTesterV2 rbt;
    // Keep track of which keys have been inserted
    mapping(NodeId => bool) public insertedKeys;
    NodeId[] public keyList;

    NodeId[] public fixtureNode = [
        NodeId.wrap(1),
        NodeId.wrap(2),
        NodeId.wrap(3),
        NodeId.wrap(4),
        NodeId.wrap(5),
        NodeId.wrap(6),
        NodeId.wrap(7),
        NodeId.wrap(8),
        NodeId.wrap(9),
        NodeId.wrap(10),
        NodeId.wrap(11),
        NodeId.wrap(12),
        NodeId.wrap(13)
    ];

    constructor(RedBlackTreeTesterV2 _rbt) {
        rbt = _rbt;
    }

    // A wrapper for the insert function
    function insert(uint8 nodeIndex, uint48 weight) public {
        NodeId node = fixtureNode[nodeIndex % fixtureNode.length];
        vm.assume(!insertedKeys[node]);
        vm.assume(weight > 0);

        _insert(node, weight);
    }

    function remove(uint8 nodeIndex) external {
        NodeId node = fixtureNode[nodeIndex % fixtureNode.length];
        vm.assume(insertedKeys[node]);
        _remove(node);
    }

    function setWeight(uint8 nodeIndex, uint48 weight) external {
        NodeId node = fixtureNode[nodeIndex % fixtureNode.length];
        vm.assume(insertedKeys[node]);
        vm.assume(weight > 0);

        rbt.setWeight(node, weight);
    }

    function _insert(NodeId node, uint256 weight) private {
        rbt.insertSmallest(node, weight);
        insertedKeys[node] = true;
        keyList.push(node);
    }

    // A wrapper for the remove function
    function _remove(NodeId node) private {
        rbt.remove(node);

        // Update our state tracking
        insertedKeys[node] = false;
        if (NodeId.unwrap(node) < keyList.length - 1) {
            keyList[NodeId.unwrap(node)] = keyList[keyList.length - 1];
        }
        keyList.pop();
    }
}


contract RBTTest is StdInvariant, Test {
    RedBlackTreeTesterV2 public rbt;
    RBTHandler public handler;
    // This function is called before each test case
    function setUp() public {
        rbt = new RedBlackTreeTesterV2();
        handler = new RBTHandler(rbt);
        targetContract(address(handler));
    }

    function invariant_treeIsValid() public view {
        assertEq(rbt.validate(), true, "TreeIsInvalid");
    }
}
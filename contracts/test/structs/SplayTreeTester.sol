// SPDX-License-Identifier: AGPL-3.0-only

/*
    SplayTreeTester.sol - mirage-manager
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

import {NodeId} from "@skalenetwork/professional-interfaces/INodes.sol";
import {SplayTree} from "../../structs/SplayTree.sol";


interface ISplayTreeTester {
    function insertSmallest(NodeId node, uint256 weight) external;
    function remove(NodeId node) external;
    function splay(NodeId node) external;
}

contract SplayTreeTester is ISplayTreeTester {
    using SplayTree for mapping(NodeId => SplayTree.Node);

    mapping(NodeId node => SplayTree.Node data) public tree;
    NodeId public root;
    NodeId public constant NULL = SplayTree.NULL;

    function insertSmallest(NodeId node, uint256 weight) external override {
        root = tree.insertSmallest(root, node, weight);
    }

    function splay(NodeId node) external override {
        root = tree.splay(node);
    }

    function remove(NodeId node) external override {
        root = tree.remove(node);
    }
}

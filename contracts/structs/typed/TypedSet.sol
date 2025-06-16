// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   NodeIdEnumSet.sol - fair-manager
 *   Copyright (C) 2025-Present SKALE Labs
 *   @author Dmytro Stebaiev
 *
 *   fair-manager is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as published
 *   by the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   fair-manager is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with fair-manager.  If not, see <https://www.gnu.org/licenses/>.
 */
pragma solidity ^0.8.24;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { NodeId } from "@skalenetwork/fair-interfaces/INodes.sol";

library TypedSet {

    struct NodeIdSet {
        EnumerableSet.UintSet inner;
    }

    function add(NodeIdSet storage set, NodeId nodeId) internal returns (bool added) {
        added = EnumerableSet.add(set.inner, NodeId.unwrap(nodeId));
    }

    function clear(NodeIdSet storage set) internal {
        EnumerableSet.clear(set.inner);
    }

    function remove(NodeIdSet storage set, NodeId nodeId) internal returns (bool removed) {
        removed = EnumerableSet.remove(set.inner, NodeId.unwrap(nodeId));
    }

    function contains(NodeIdSet storage set, NodeId nodeId) internal view returns (bool exists) {
        exists = EnumerableSet.contains(set.inner, NodeId.unwrap(nodeId));
    }

    function length(NodeIdSet storage set) internal view returns (uint256 len) {
        len = EnumerableSet.length(set.inner);
    }

    function values(NodeIdSet storage set) internal view returns (NodeId[] memory nodeIds) {
        uint256 size = EnumerableSet.length(set.inner);
        nodeIds = new NodeId[](size);
        for (uint256 i = 0; i < size; ++i) {
            nodeIds[i] = NodeId.wrap(EnumerableSet.at(set.inner, i));
        }
    }

    function at(NodeIdSet storage set, uint256 index) internal view returns (NodeId nodeId) {
        nodeId = NodeId.wrap(EnumerableSet.at(set.inner, index));
    }
}

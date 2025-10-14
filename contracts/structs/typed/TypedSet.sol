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
import { NodeId } from "@skalenetwork/fair-manager-interfaces/INodes.sol";

/**
 * @title TypedSet
 * @author SKALE Labs
 * @dev Library providing type-safe wrappers around OpenZeppelin's EnumerableSet
 * Implements strongly-typed sets for NodeId to prevent type confusion and improve code safety and readability.
 */
library TypedSet {

    /// @dev Set of NodeIds with enumeration support
    struct NodeIdSet {
        EnumerableSet.UintSet inner;
    }

    // ----------
    //  Internal
    // ----------

    // NodeIdSet

    /// @dev Adds a NodeId to the set
    function add(NodeIdSet storage set, NodeId nodeId) internal returns (bool added) {
        added = EnumerableSet.add(set.inner, NodeId.unwrap(nodeId));
    }

    /// @dev Removes all elements from the set
    function clear(NodeIdSet storage set) internal {
        EnumerableSet.clear(set.inner);
    }

    /// @dev Removes a NodeId from the set
    function remove(NodeIdSet storage set, NodeId nodeId) internal returns (bool removed) {
        removed = EnumerableSet.remove(set.inner, NodeId.unwrap(nodeId));
    }

    // ----------
    //  Internal views
    // ----------

    // NodeIdSet

    /// @dev Checks if a NodeId exists in the set
    function contains(NodeIdSet storage set, NodeId nodeId) internal view returns (bool exists) {
        exists = EnumerableSet.contains(set.inner, NodeId.unwrap(nodeId));
    }

    /// @dev Returns the number of NodeIds in the set
    function length(NodeIdSet storage set) internal view returns (uint256 len) {
        len = EnumerableSet.length(set.inner);
    }

    /// @dev Returns all NodeIds in the set as an array
    function values(NodeIdSet storage set) internal view returns (NodeId[] memory nodeIds) {
        uint256 size = EnumerableSet.length(set.inner);
        nodeIds = new NodeId[](size);
        for (uint256 i = 0; i < size; ++i) {
            nodeIds[i] = NodeId.wrap(EnumerableSet.at(set.inner, i));
        }
    }

    /// @dev Returns the NodeId at a specific index in the set
    function at(NodeIdSet storage set, uint256 index) internal view returns (NodeId nodeId) {
        nodeId = NodeId.wrap(EnumerableSet.at(set.inner, index));
    }
}

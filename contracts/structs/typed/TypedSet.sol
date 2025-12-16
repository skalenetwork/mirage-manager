// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   NodeIdEnumSet.sol - fair-manager
 *   Copyright (C) 2025-Present SKALE Labs
 *   @author Dmytro Stebaiev
 *   @author Eduardo Vasques
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

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {NodeId} from "@skalenetwork/fair-manager-interfaces/INodes.sol";

/**
 * @title TypedSet Library
 * @author Dmytro Stebaiev
 * @author Eduardo Vasques
 * @notice Library providing type-safe wrappers around OpenZeppelin's EnumerableSet
 * @dev Implements strongly-typed sets for NodeId to prevent type confusion and improve code safety and readability.
 */
library TypedSet {
    /// @notice Set of NodeIds with enumeration support
    struct NodeIdSet {
        EnumerableSet.UintSet inner;
    }

    // ----------
    //  Internal
    // ----------

    // NodeIdSet

    /**
     * @notice Adds a NodeId to the set
     * @param set The NodeIdSet to modify
     * @param nodeId The NodeId to add to the set
     * @return added True if the nodeId was added (was not already present), false otherwise
     */
    function add(NodeIdSet storage set, NodeId nodeId) internal returns (bool added) {
        added = EnumerableSet.add(set.inner, NodeId.unwrap(nodeId));
    }

    /**
     * @notice Removes all elements from the set
     * @param set The NodeIdSet to clear
     */
    function clear(NodeIdSet storage set) internal {
        EnumerableSet.clear(set.inner);
    }

    /**
     * @notice Removes a NodeId from the set
     * @param set The NodeIdSet to modify
     * @param nodeId The NodeId to remove from the set
     * @return removed True if the nodeId was removed (was present), false otherwise
     */
    function remove(NodeIdSet storage set, NodeId nodeId) internal returns (bool removed) {
        removed = EnumerableSet.remove(set.inner, NodeId.unwrap(nodeId));
    }

    // ----------
    //  Internal views
    // ----------

    // NodeIdSet

    /**
     * @notice Checks if a NodeId exists in the set
     * @param set The NodeIdSet to query
     * @param nodeId The NodeId to check for existence
     * @return exists True if the nodeId is in the set, false otherwise
     */
    function contains(NodeIdSet storage set, NodeId nodeId) internal view returns (bool exists) {
        exists = EnumerableSet.contains(set.inner, NodeId.unwrap(nodeId));
    }

    /**
     * @notice Returns the number of NodeIds in the set
     * @param set The NodeIdSet to query
     * @return len The number of elements in the set
     */
    function length(NodeIdSet storage set) internal view returns (uint256 len) {
        len = EnumerableSet.length(set.inner);
    }

    /**
     * @notice Returns all NodeIds in the set as an array
     * @dev Order is not guaranteed and may change when adding/removing elements
     * @param set The NodeIdSet to query
     * @return nodeIds Array containing all NodeIds in the set
     */
    function values(NodeIdSet storage set) internal view returns (NodeId[] memory nodeIds) {
        uint256 size = EnumerableSet.length(set.inner);
        nodeIds = new NodeId[](size);
        for (uint256 i = 0; i < size; ++i) {
            nodeIds[i] = NodeId.wrap(EnumerableSet.at(set.inner, i));
        }
    }

    /**
     * @notice Returns the NodeId at a specific index in the set
     * @dev Reverts if index is out of bounds
     * @param set The NodeIdSet to query
     * @param index The zero-based index of the element to retrieve
     * @return nodeId The NodeId at the specified index
     */
    function at(NodeIdSet storage set, uint256 index) internal view returns (NodeId nodeId) {
        nodeId = NodeId.wrap(EnumerableSet.at(set.inner, index));
    }
}

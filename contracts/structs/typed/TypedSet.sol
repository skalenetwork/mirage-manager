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
 * @notice A library for creating typed sets.
 */
library TypedSet {

    struct NodeIdSet {
        EnumerableSet.UintSet inner;
    }

    // ----------
    //  Internal
    // ----------

    // NodeIdSet

    /**
     * @notice Adds a NodeId to the set.
     * @param set The set to add to.
     * @param nodeId The NodeId to add.
     * @return added True if the NodeId was added, false otherwise.
     */
    function add(NodeIdSet storage set, NodeId nodeId) internal returns (bool added) {
        added = EnumerableSet.add(set.inner, NodeId.unwrap(nodeId));
    }

    /**
     * @notice Clears the set.
     * @param set The set to clear.
     */
    function clear(NodeIdSet storage set) internal {
        EnumerableSet.clear(set.inner);
    }

    /**
     * @notice Removes a NodeId from the set.
     * @param set The set to remove from.
     * @param nodeId The NodeId to remove.
     * @return removed True if the NodeId was removed, false otherwise.
     */
    function remove(NodeIdSet storage set, NodeId nodeId) internal returns (bool removed) {
        removed = EnumerableSet.remove(set.inner, NodeId.unwrap(nodeId));
    }

    // ----------
    //  Internal views
    // ----------

    // NodeIdSet

    /**
     * @notice Checks if a NodeId is in the set.
     * @param set The set to check.
     * @param nodeId The NodeId to check for.
     * @return exists True if the NodeId is in the set, false otherwise.
     */
    function contains(NodeIdSet storage set, NodeId nodeId) internal view returns (bool exists) {
        exists = EnumerableSet.contains(set.inner, NodeId.unwrap(nodeId));
    }

    /**
     * @notice Gets the number of NodeIds in the set.
     * @param set The set to get the length of.
     * @return len The number of NodeIds in the set.
     */
    function length(NodeIdSet storage set) internal view returns (uint256 len) {
        len = EnumerableSet.length(set.inner);
    }

    /**
     * @notice Gets an array of all NodeIds in the set.
     * @param set The set to get the values of.
     * @return nodeIds An array of all NodeIds in the set.
     */
    function values(NodeIdSet storage set) internal view returns (NodeId[] memory nodeIds) {
        uint256 size = EnumerableSet.length(set.inner);
        nodeIds = new NodeId[](size);
        for (uint256 i = 0; i < size; ++i) {
            nodeIds[i] = NodeId.wrap(EnumerableSet.at(set.inner, i));
        }
    }

    /**
     * @notice Gets the NodeId at a specific index in the set.
     * @param set The set to get the NodeId from.
     * @param index The index of the NodeId to get.
     * @return nodeId The NodeId at the specified index.
     */
    function at(NodeIdSet storage set, uint256 index) internal view returns (NodeId nodeId) {
        nodeId = NodeId.wrap(EnumerableSet.at(set.inner, index));
    }

}

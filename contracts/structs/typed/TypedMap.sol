// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   NodeIdEnumSet.sol - mirage-manager
 *   Copyright (C) 2025-Present SKALE Labs
 *   @author Dmytro Stebaiev
 *
 *   mirage-manager is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as published
 *   by the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   mirage-manager is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with mirage-manager.  If not, see <https://www.gnu.org/licenses/>.
 */
pragma solidity ^0.8.24;

import { EnumerableMap } from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import { NodeId } from "@skalenetwork/professional-interfaces/INodes.sol";
import { Mirage } from "@skalenetwork/professional-interfaces/units.sol";

import { TypedSet } from "./TypedSet.sol";

library TypedMap {
    using TypedSet for TypedSet.NodeIdSet;

    struct AddressToNodeIdMap {
        EnumerableMap.AddressToUintMap inner;
    }

    struct AddressToNodeIdSetMap {
        mapping(address => TypedSet.NodeIdSet) inner;
    }

    struct NodeIdToMirageMap {
        EnumerableMap.UintToUintMap inner;
    }

    // ----------
    //  Internal
    // ----------

    // AddressToNodeIdMap
    function set(AddressToNodeIdMap storage map, address key, NodeId value) internal returns (bool added) {
        added = EnumerableMap.set(map.inner, key, NodeId.unwrap(value));
    }

    function remove(AddressToNodeIdMap storage map, address key) internal returns (bool removed) {
        removed = EnumerableMap.remove(map.inner, key);
    }

    // AddressToNodeIdSetMap

    function add(AddressToNodeIdSetMap storage map, address key, NodeId nodeId) internal returns (bool added) {
        added = map.inner[key].add(nodeId);
    }

    function remove(AddressToNodeIdSetMap storage map, address key, NodeId nodeId) internal returns (bool removed) {
        removed = map.inner[key].remove(nodeId);
    }

    // NodeIdToMirageMap

    function set(NodeIdToMirageMap storage map, NodeId key, Mirage value) internal returns (bool added) {
        added = EnumerableMap.set(map.inner, NodeId.unwrap(key), Mirage.unwrap(value));
    }

    function remove(NodeIdToMirageMap storage map, NodeId key) internal returns (bool removed) {
        removed = EnumerableMap.remove(map.inner, NodeId.unwrap(key));
    }

    // --------------
    //  Internal Views
    // --------------

    // AddressToNodeIdMap
    function contains(AddressToNodeIdMap storage map, address key) internal view returns (bool result) {
        result = EnumerableMap.contains(map.inner, key);
    }

    function length(AddressToNodeIdMap storage map) internal view returns (uint256 len) {
        len = EnumerableMap.length(map.inner);
    }

    function get(AddressToNodeIdMap storage map, address key) internal view returns (NodeId nodeId) {
        nodeId = NodeId.wrap(EnumerableMap.get(map.inner, key));
    }

    function tryGet(AddressToNodeIdMap storage map, address key) internal view returns (bool success, NodeId nodeId) {
        uint256 raw;
        (success, raw) = EnumerableMap.tryGet(map.inner, key);
        nodeId = NodeId.wrap(raw);
    }

    // AddressToNodeIdMap
    function lengthOf(AddressToNodeIdSetMap storage map, address key) internal view returns (uint256 len) {
        len = map.inner[key].length();
    }

    function getValuesAt(AddressToNodeIdSetMap storage map, address key) internal view returns (NodeId[] memory ids) {
        ids = map.inner[key].values();
    }

    function isSet(AddressToNodeIdSetMap storage map, address key, NodeId nodeId) internal view returns (bool result) {
        result = map.inner[key].contains(nodeId);
    }

    // NodeIdToMirageMap

    function get(NodeIdToMirageMap storage map, NodeId key) internal view returns (Mirage value) {
        return Mirage.wrap(EnumerableMap.get(map.inner, NodeId.unwrap(key)));
    }

    function contains(NodeIdToMirageMap storage map, NodeId key) internal view returns (bool result) {
        result = EnumerableMap.contains(map.inner, NodeId.unwrap(key));
    }

    function tryGet(NodeIdToMirageMap storage map, NodeId key) internal view returns (bool success, Mirage value) {
        uint256 rawValue;
        (success, rawValue) = EnumerableMap.tryGet(map.inner, NodeId.unwrap(key));
        value = Mirage.wrap(rawValue);
    }
}

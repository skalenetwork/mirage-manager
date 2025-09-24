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

import { EnumerableMap } from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import { NodeId } from "@skalenetwork/fair-manager-interfaces/INodes.sol";
import { Fair } from "@skalenetwork/fair-manager-interfaces/units.sol";
import { Credit, Holder } from "../../utils/Fund.sol";
import { TypedSet } from "./TypedSet.sol";

library TypedMap {
    using TypedSet for TypedSet.NodeIdSet;

    struct AddressToNodeIdMap {
        EnumerableMap.AddressToUintMap inner;
    }

    struct AddressToNodeIdSetMap {
        mapping(address => TypedSet.NodeIdSet) inner;
    }

    struct NodeIdToBytes32Map {
        EnumerableMap.UintToBytes32Map inner;
    }

    struct NodeIdToFairMap {
        EnumerableMap.UintToUintMap inner;
    }

    struct HolderToCreditMap {
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

    // NodeIdToBytes32Map

    function clear(NodeIdToBytes32Map storage map) internal {
        EnumerableMap.clear(map.inner);
    }

    function set(NodeIdToBytes32Map storage map, NodeId key, bytes32 value) internal returns (bool added) {
        added = EnumerableMap.set(map.inner, NodeId.unwrap(key), value);
    }

    // NodeIdToFairMap

    function set(NodeIdToFairMap storage map, NodeId key, Fair value) internal returns (bool added) {
        added = EnumerableMap.set(map.inner, NodeId.unwrap(key), Fair.unwrap(value));
    }

    function remove(NodeIdToFairMap storage map, NodeId key) internal returns (bool removed) {
        removed = EnumerableMap.remove(map.inner, NodeId.unwrap(key));
    }

    // HolderToCreditMap

    function set(HolderToCreditMap storage map, Holder key, Credit value) internal returns (bool added) {
        added = EnumerableMap.set(map.inner, Holder.unwrap(key), Credit.unwrap(value));
    }

    function remove(HolderToCreditMap storage map, Holder key) internal returns (bool removed) {
        removed = EnumerableMap.remove(map.inner, Holder.unwrap(key));
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

    // NodeIdToBytes32Map

    function contains(NodeIdToBytes32Map storage map, NodeId key) internal view returns (bool result) {
        result = EnumerableMap.contains(map.inner, NodeId.unwrap(key));
    }

    function length(NodeIdToBytes32Map storage map) internal view returns (uint256 len) {
        len = EnumerableMap.length(map.inner);
    }

    function tryGet(NodeIdToBytes32Map storage map, NodeId key) internal view returns (bool success, bytes32 value) {
        (success, value) = EnumerableMap.tryGet(map.inner, NodeId.unwrap(key));
    }

    // NodeIdToFairMap

    function get(NodeIdToFairMap storage map, NodeId key) internal view returns (Fair value) {
        return Fair.wrap(EnumerableMap.get(map.inner, NodeId.unwrap(key)));
    }

    function contains(NodeIdToFairMap storage map, NodeId key) internal view returns (bool result) {
        result = EnumerableMap.contains(map.inner, NodeId.unwrap(key));
    }

    function tryGet(NodeIdToFairMap storage map, NodeId key) internal view returns (bool success, Fair value) {
        uint256 rawValue;
        (success, rawValue) = EnumerableMap.tryGet(map.inner, NodeId.unwrap(key));
        value = Fair.wrap(rawValue);
    }

    function keys(NodeIdToFairMap storage map) internal view returns (NodeId[] memory nodes){
        uint256[] memory values = EnumerableMap.keys(map.inner);
        nodes = new NodeId[](values.length);
        uint256 loops = values.length;
        for (uint256 i = 0; i < loops; ++i) {
            nodes[i] = NodeId.wrap(values[i]);
        }
    }

    // HolderToCreditMap

    function get(HolderToCreditMap storage map, Holder key) internal view returns (Credit value) {
        return Credit.wrap(EnumerableMap.get(map.inner, Holder.unwrap(key)));
    }

    function contains(HolderToCreditMap storage map, Holder key) internal view returns (bool result) {
        result = EnumerableMap.contains(map.inner, Holder.unwrap(key));
    }

    function tryGet(HolderToCreditMap storage map, Holder key) internal view returns (bool success, Credit value) {
        uint256 rawValue;
        (success, rawValue) = EnumerableMap.tryGet(map.inner, Holder.unwrap(key));
        value = Credit.wrap(rawValue);
    }

    function keys(HolderToCreditMap storage map) internal view returns (Holder[] memory nodes){
        uint256[] memory values = EnumerableMap.keys(map.inner);
        nodes = new Holder[](values.length);
        uint256 loops = values.length;
        for (uint256 i = 0; i < loops; ++i) {
            nodes[i] = Holder.wrap(values[i]);
        }
    }

    function length(HolderToCreditMap storage map) internal view returns (uint256 len) {
        return EnumerableMap.length(map.inner);
    }
}

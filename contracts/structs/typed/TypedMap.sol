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

/**
 * @title TypedMap
 * @notice A library for creating typed maps.
 */
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
    /**
     * @notice Sets a key-value pair in the map.
     * @param map The map to set the pair in.
     * @param key The key to set.
     * @param value The value to set.
     * @return added True if the pair was added, false if it was updated.
     */
    function set(AddressToNodeIdMap storage map, address key, NodeId value) internal returns (bool added) {
        added = EnumerableMap.set(map.inner, key, NodeId.unwrap(value));
    }

    /**
     * @notice Removes a key-value pair from the map.
     * @param map The map to remove the pair from.
     * @param key The key to remove.
     * @return removed True if the pair was removed, false otherwise.
     */
    function remove(AddressToNodeIdMap storage map, address key) internal returns (bool removed) {
        removed = EnumerableMap.remove(map.inner, key);
    }

    // AddressToNodeIdSetMap

    /**
     * @notice Adds a NodeId to the set of a key.
     * @param map The map to add the NodeId to.
     * @param key The key to add the NodeId to.
     * @param nodeId The NodeId to add.
     * @return added True if the NodeId was added, false otherwise.
     */
    function add(AddressToNodeIdSetMap storage map, address key, NodeId nodeId) internal returns (bool added) {
        added = map.inner[key].add(nodeId);
    }

    /**
     * @notice Removes a NodeId from the set of a key.
     * @param map The map to remove the NodeId from.
     * @param key The key to remove the NodeId from.
     * @param nodeId The NodeId to remove.
     * @return removed True if the NodeId was removed, false otherwise.
     */
    function remove(AddressToNodeIdSetMap storage map, address key, NodeId nodeId) internal returns (bool removed) {
        removed = map.inner[key].remove(nodeId);
    }

    // NodeIdToBytes32Map

    /**
     * @notice Clears the map.
     * @param map The map to clear.
     */
    function clear(NodeIdToBytes32Map storage map) internal {
        EnumerableMap.clear(map.inner);
    }

    /**
     * @notice Sets a key-value pair in the map.
     * @param map The map to set the pair in.
     * @param key The key to set.
     * @param value The value to set.
     * @return added True if the pair was added, false otherwise.
     */
    function set(NodeIdToBytes32Map storage map, NodeId key, bytes32 value) internal returns (bool added) {
        added = EnumerableMap.set(map.inner, NodeId.unwrap(key), value);
    }

    // NodeIdToFairMap

    /**
     * @notice Sets a key-value pair in the map.
     * @param map The map to set the pair in.
     * @param key The key to set.
     * @param value The value to set.
     * @return added True if the pair was added, false otherwise.
     */
    function set(NodeIdToFairMap storage map, NodeId key, Fair value) internal returns (bool added) {
        added = EnumerableMap.set(map.inner, NodeId.unwrap(key), Fair.unwrap(value));
    }

    /**
     * @notice Removes a key-value pair from the map.
     * @param map The map to remove the pair from.
     * @param key The key to remove.
     * @return removed True if the pair was removed, false otherwise.
     */
    function remove(NodeIdToFairMap storage map, NodeId key) internal returns (bool removed) {
        removed = EnumerableMap.remove(map.inner, NodeId.unwrap(key));
    }

    // HolderToCreditMap

    /**
     * @notice Sets a key-value pair in the map.
     * @param map The map to set the pair in.
     * @param key The key to set.
     * @param value The value to set.
     * @return added True if the pair was added, false otherwise.
     */
    function set(HolderToCreditMap storage map, Holder key, Credit value) internal returns (bool added) {
        added = EnumerableMap.set(map.inner, Holder.unwrap(key), Credit.unwrap(value));
    }

    /**
     * @notice Removes a key-value pair from the map.
     * @param map The map to remove the pair from.
     * @param key The key to remove.
     * @return removed True if the pair was removed, false otherwise.
     */
    function remove(HolderToCreditMap storage map, Holder key) internal returns (bool removed) {
        removed = EnumerableMap.remove(map.inner, Holder.unwrap(key));
    }

    // --------------
    //  Internal Views
    // --------------

    // AddressToNodeIdMap
    /**
     * @notice Checks if a key is in the map.
     * @param map The map to check.
     * @param key The key to check for.
     * @return result True if the key is in the map, false otherwise.
     */
    function contains(AddressToNodeIdMap storage map, address key) internal view returns (bool result) {
        result = EnumerableMap.contains(map.inner, key);
    }

    /**
     * @notice Gets the number of key-value pairs in the map.
     * @param map The map to get the length of.
     * @return len The number of key-value pairs in the map.
     */
    function length(AddressToNodeIdMap storage map) internal view returns (uint256 len) {
        len = EnumerableMap.length(map.inner);
    }

    /**
     * @notice Gets the value of a key.
     * @param map The map to get the value from.
     * @param key The key to get the value of.
     * @return nodeId The value of the key.
     */
    function get(AddressToNodeIdMap storage map, address key) internal view returns (NodeId nodeId) {
        nodeId = NodeId.wrap(EnumerableMap.get(map.inner, key));
    }

    /**
     * @notice Tries to get the value of a key.
     * @param map The map to get the value from.
     * @param key The key to get the value of.
     * @return success True if the key was found, false otherwise.
     * @return nodeId The value of the key.
     */
    function tryGet(AddressToNodeIdMap storage map, address key) internal view returns (bool success, NodeId nodeId) {
        uint256 raw;
        (success, raw) = EnumerableMap.tryGet(map.inner, key);
        nodeId = NodeId.wrap(raw);
    }

    // AddressToNodeIdMap
    /**
     * @notice Gets the number of NodeIds in the set of a key.
     * @param map The map to get the length of.
     * @param key The key to get the length of.
     * @return len The number of NodeIds in the set of the key.
     */
    function lengthOf(AddressToNodeIdSetMap storage map, address key) internal view returns (uint256 len) {
        len = map.inner[key].length();
    }

    /**
     * @notice Gets the values of the set of a key.
     * @param map The map to get the values from.
     * @param key The key to get the values of.
     * @return ids The values of the set of the key.
     */
    function getValuesAt(AddressToNodeIdSetMap storage map, address key) internal view returns (NodeId[] memory ids) {
        ids = map.inner[key].values();
    }

    /**
     * @notice Checks if a NodeId is in the set of a key.
     * @param map The map to check.
     * @param key The key to check.
     * @param nodeId The NodeId to check for.
     * @return result True if the NodeId is in the set of the key, false otherwise.
     */
    function isSet(AddressToNodeIdSetMap storage map, address key, NodeId nodeId) internal view returns (bool result) {
        result = map.inner[key].contains(nodeId);
    }

    // NodeIdToBytes32Map

    /**
     * @notice Checks if a key is in the map.
     * @param map The map to check.
     * @param key The key to check for.
     * @return result True if the key is in the map, false otherwise.
     */
    function contains(NodeIdToBytes32Map storage map, NodeId key) internal view returns (bool result) {
        result = EnumerableMap.contains(map.inner, NodeId.unwrap(key));
    }

    /**
     * @notice Gets the number of key-value pairs in the map.
     * @param map The map to get the length of.
     * @return len The number of key-value pairs in the map.
     */
    function length(NodeIdToBytes32Map storage map) internal view returns (uint256 len) {
        len = EnumerableMap.length(map.inner);
    }

    /**
     * @notice Tries to get the value of a key.
     * @param map The map to get the value from.
     * @param key The key to get the value of.
     * @return success True if the key was found, false otherwise.
     * @return value The value of the key.
     */
    function tryGet(NodeIdToBytes32Map storage map, NodeId key) internal view returns (bool success, bytes32 value) {
        (success, value) = EnumerableMap.tryGet(map.inner, NodeId.unwrap(key));
    }

    // NodeIdToFairMap

    /**
     * @notice Gets the value of a key.
     * @param map The map to get the value from.
     * @param key The key to get the value of.
     * @return value The value of the key.
     */
    function get(NodeIdToFairMap storage map, NodeId key) internal view returns (Fair value) {
        return Fair.wrap(EnumerableMap.get(map.inner, NodeId.unwrap(key)));
    }

    /**
     * @notice Checks if a key is in the map.
     * @param map The map to check.
     * @param key The key to check for.
     * @return result True if the key is in the map, false otherwise.
     */
    function contains(NodeIdToFairMap storage map, NodeId key) internal view returns (bool result) {
        result = EnumerableMap.contains(map.inner, NodeId.unwrap(key));
    }

    /**
     * @notice Tries to get the value of a key.
     * @param map The map to get the value from.
     * @param key The key to get the value of.
     * @return success True if the key was found, false otherwise.
     * @return value The value of the key.
     */
    function tryGet(NodeIdToFairMap storage map, NodeId key) internal view returns (bool success, Fair value) {
        uint256 rawValue;
        (success, rawValue) = EnumerableMap.tryGet(map.inner, NodeId.unwrap(key));
        value = Fair.wrap(rawValue);
    }

    /**
     * @notice Gets an array of all keys in the map.
     * @param map The map to get the keys of.
     * @return nodes An array of all keys in the map.
     */
    function keys(NodeIdToFairMap storage map) internal view returns (NodeId[] memory nodes) {
        uint256[] memory values = EnumerableMap.keys(map.inner);
        nodes = new NodeId[](values.length);
        uint256 loops = values.length;
        for (uint256 i = 0; i < loops; ++i) {
            nodes[i] = NodeId.wrap(values[i]);
        }
    }

    // HolderToCreditMap

    /**
     * @notice Gets the value of a key.
     * @param map The map to get the value from.
     * @param key The key to get the value of.
     * @return value The value of the key.
     */
    function get(HolderToCreditMap storage map, Holder key) internal view returns (Credit value) {
        return Credit.wrap(EnumerableMap.get(map.inner, Holder.unwrap(key)));
    }

    /**
     * @notice Checks if a key is in the map.
     * @param map The map to check.
     * @param key The key to check for.
     * @return result True if the key is in the map, false otherwise.
     */
    function contains(HolderToCreditMap storage map, Holder key) internal view returns (bool result) {
        result = EnumerableMap.contains(map.inner, Holder.unwrap(key));
    }

    /**
     * @notice Tries to get the value of a key.
     * @param map The map to get the value from.
     * @param key The key to get the value of.
     * @return success True if the key was found, false otherwise.
     * @return value The value of the key.
     */
    function tryGet(HolderToCreditMap storage map, Holder key) internal view returns (bool success, Credit value) {
        uint256 rawValue;
        (success, rawValue) = EnumerableMap.tryGet(map.inner, Holder.unwrap(key));
        value = Credit.wrap(rawValue);
    }

    /**
     * @notice Gets an array of all keys in the map.
     * @param map The map to get the keys of.
     * @return nodes An array of all keys in the map.
     */
    function keys(HolderToCreditMap storage map) internal view returns (Holder[] memory nodes) {
        uint256[] memory values = EnumerableMap.keys(map.inner);
        nodes = new Holder[](values.length);
        uint256 loops = values.length;
        for (uint256 i = 0; i < loops; ++i) {
            nodes[i] = Holder.wrap(values[i]);
        }
    }

    /**
     * @notice Gets the number of key-value pairs in the map.
     * @param map The map to get the length of.
     * @return len The number of key-value pairs in the map.
     */
    function length(HolderToCreditMap storage map) internal view returns (uint256 len) {
        return EnumerableMap.length(map.inner);
    }

}

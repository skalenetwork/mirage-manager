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

import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {NodeId} from "@skalenetwork/fair-manager-interfaces/INodes.sol";
import {Fair} from "@skalenetwork/fair-manager-interfaces/units.sol";
import {Credit, Holder} from "../../utils/Fund.sol";
import {TypedSet} from "./TypedSet.sol";

/**
 * @title TypedMap Library
 * @author Dmytro Stebaiev
 * @author Eduardo Vasques
 * @notice Library providing type-safe wrappers around OpenZeppelin's EnumerableMap
 * @dev Implements strongly-typed maps for NodeId, Fair, Credit, and Holder types
 * to prevent type confusion and improve code safety and readability.
 */
library TypedMap {
    using TypedSet for TypedSet.NodeIdSet;

    /// @notice Map from addresses to NodeIds with enumeration support
    struct AddressToNodeIdMap {
        EnumerableMap.AddressToUintMap inner;
    }

    /// @notice Map from addresses to sets of NodeIds
    struct AddressToNodeIdSetMap {
        mapping(address => TypedSet.NodeIdSet) inner;
    }

    /// @notice Map from NodeIds to bytes32 values with enumeration support
    struct NodeIdToBytes32Map {
        EnumerableMap.UintToBytes32Map inner;
    }

    /// @notice Map from NodeIds to Fair values with enumeration support
    struct NodeIdToFairMap {
        EnumerableMap.UintToUintMap inner;
    }

    /// @notice Map from Holders to Credit values with enumeration support
    struct HolderToCreditMap {
        EnumerableMap.UintToUintMap inner;
    }

    // ----------
    //  Internal
    // ----------

    // AddressToNodeIdMap

    /**
     * @notice Sets or updates a NodeId for a given address key
     * @param map The AddressToNodeIdMap to modify
     * @param key The address key
     * @param value The NodeId value to associate with the key
     * @return added True if the key was added (was not already present), false if updated
     */
    function set(AddressToNodeIdMap storage map, address key, NodeId value) internal returns (bool added) {
        added = EnumerableMap.set(map.inner, key, NodeId.unwrap(value));
    }

    /**
     * @notice Removes an address key and its associated NodeId from the map
     * @param map The AddressToNodeIdMap to modify
     * @param key The address key to remove
     * @return removed True if the key was removed (was present), false otherwise
     */
    function remove(AddressToNodeIdMap storage map, address key) internal returns (bool removed) {
        removed = EnumerableMap.remove(map.inner, key);
    }

    // AddressToNodeIdSetMap

    /**
     * @notice Adds a NodeId to the set associated with an address key
     * @param map The AddressToNodeIdSetMap to modify
     * @param key The address key
     * @param nodeId The NodeId to add to the set
     * @return added True if the nodeId was added (was not already in the set), false otherwise
     */
    function add(AddressToNodeIdSetMap storage map, address key, NodeId nodeId) internal returns (bool added) {
        added = map.inner[key].add(nodeId);
    }

    /**
     * @notice Removes a NodeId from the set associated with an address key
     * @param map The AddressToNodeIdSetMap to modify
     * @param key The address key
     * @param nodeId The NodeId to remove from the set
     * @return removed True if the nodeId was removed (was in the set), false otherwise
     */
    function remove(AddressToNodeIdSetMap storage map, address key, NodeId nodeId) internal returns (bool removed) {
        removed = map.inner[key].remove(nodeId);
    }

    // NodeIdToBytes32Map

    /**
     * @notice Removes all elements from the map
     * @param map The NodeIdToBytes32Map to clear
     */
    function clear(NodeIdToBytes32Map storage map) internal {
        EnumerableMap.clear(map.inner);
    }

    /**
     * @notice Sets or updates a bytes32 value for a given NodeId key
     * @param map The NodeIdToBytes32Map to modify
     * @param key The NodeId key
     * @param value The bytes32 value to associate with the key
     * @return added True if the key was added (was not already present), false if updated
     */
    function set(NodeIdToBytes32Map storage map, NodeId key, bytes32 value) internal returns (bool added) {
        added = EnumerableMap.set(map.inner, NodeId.unwrap(key), value);
    }

    // NodeIdToFairMap

    /**
     * @notice Sets or updates a Fair value for a given NodeId key
     * @param map The NodeIdToFairMap to modify
     * @param key The NodeId key
     * @param value The Fair value to associate with the key
     * @return added True if the key was added (was not already present), false if updated
     */
    function set(NodeIdToFairMap storage map, NodeId key, Fair value) internal returns (bool added) {
        added = EnumerableMap.set(map.inner, NodeId.unwrap(key), Fair.unwrap(value));
    }

    /**
     * @notice Removes a NodeId key and its associated Fair value from the map
     * @param map The NodeIdToFairMap to modify
     * @param key The NodeId key to remove
     * @return removed True if the key was removed (was present), false otherwise
     */
    function remove(NodeIdToFairMap storage map, NodeId key) internal returns (bool removed) {
        removed = EnumerableMap.remove(map.inner, NodeId.unwrap(key));
    }

    // HolderToCreditMap

    /**
     * @notice Sets or updates a Credit value for a given Holder key
     * @param map The HolderToCreditMap to modify
     * @param key The Holder key
     * @param value The Credit value to associate with the key
     * @return added True if the key was added (was not already present), false if updated
     */
    function set(HolderToCreditMap storage map, Holder key, Credit value) internal returns (bool added) {
        added = EnumerableMap.set(map.inner, Holder.unwrap(key), Credit.unwrap(value));
    }

    /**
     * @notice Removes a Holder key and its associated Credit value from the map
     * @param map The HolderToCreditMap to modify
     * @param key The Holder key to remove
     * @return removed True if the key was removed (was present), false otherwise
     */
    function remove(HolderToCreditMap storage map, Holder key) internal returns (bool removed) {
        removed = EnumerableMap.remove(map.inner, Holder.unwrap(key));
    }

    // --------------
    //  Internal Views
    // --------------

    // AddressToNodeIdMap

    /**
     * @notice Checks if an address key exists in the map
     * @param map The AddressToNodeIdMap to query
     * @param key The address key to check for existence
     * @return result True if the key is in the map, false otherwise
     */
    function contains(AddressToNodeIdMap storage map, address key) internal view returns (bool result) {
        result = EnumerableMap.contains(map.inner, key);
    }

    /**
     * @notice Returns the number of key-value pairs in the map
     * @param map The AddressToNodeIdMap to query
     * @return len The number of elements in the map
     */
    function length(AddressToNodeIdMap storage map) internal view returns (uint256 len) {
        len = EnumerableMap.length(map.inner);
    }

    /**
     * @notice Gets the NodeId value associated with an address key
     * @dev Reverts if the key is not in the map
     * @param map The AddressToNodeIdMap to query
     * @param key The address key to look up
     * @return nodeId The NodeId value associated with the key
     */
    function get(AddressToNodeIdMap storage map, address key) internal view returns (NodeId nodeId) {
        nodeId = NodeId.wrap(EnumerableMap.get(map.inner, key));
    }

    /**
     * @notice Attempts to get the NodeId value associated with an address key
     * @param map The AddressToNodeIdMap to query
     * @param key The address key to look up
     * @return success True if the key exists in the map, false otherwise
     * @return nodeId The NodeId value if the key exists, wrapped zero otherwise
     */
    function tryGet(AddressToNodeIdMap storage map, address key) internal view returns (bool success, NodeId nodeId) {
        uint256 raw;
        (success, raw) = EnumerableMap.tryGet(map.inner, key);
        nodeId = NodeId.wrap(raw);
    }

    // AddressToNodeIdMap

    /**
     * @notice Returns the number of NodeIds in the set associated with an address key
     * @param map The AddressToNodeIdSetMap to query
     * @param key The address key
     * @return len The number of NodeIds in the set
     */
    function lengthOf(AddressToNodeIdSetMap storage map, address key) internal view returns (uint256 len) {
        len = map.inner[key].length();
    }

    /**
     * @notice Gets all NodeIds in the set associated with an address key
     * @param map The AddressToNodeIdSetMap to query
     * @param key The address key
     * @return ids Array containing all NodeIds in the set
     */
    function getValuesAt(AddressToNodeIdSetMap storage map, address key) internal view returns (NodeId[] memory ids) {
        ids = map.inner[key].values();
    }

    /**
     * @notice Checks if a NodeId exists in the set associated with an address key
     * @param map The AddressToNodeIdSetMap to query
     * @param key The address key
     * @param nodeId The NodeId to check for existence
     * @return result True if the nodeId is in the set, false otherwise
     */
    function isSet(AddressToNodeIdSetMap storage map, address key, NodeId nodeId) internal view returns (bool result) {
        result = map.inner[key].contains(nodeId);
    }

    // NodeIdToBytes32Map

    /**
     * @notice Checks if a NodeId key exists in the map
     * @param map The NodeIdToBytes32Map to query
     * @param key The NodeId key to check for existence
     * @return result True if the key is in the map, false otherwise
     */
    function contains(NodeIdToBytes32Map storage map, NodeId key) internal view returns (bool result) {
        result = EnumerableMap.contains(map.inner, NodeId.unwrap(key));
    }

    /**
     * @notice Returns the number of key-value pairs in the map
     * @param map The NodeIdToBytes32Map to query
     * @return len The number of elements in the map
     */
    function length(NodeIdToBytes32Map storage map) internal view returns (uint256 len) {
        len = EnumerableMap.length(map.inner);
    }

    /**
     * @notice Attempts to get the bytes32 value associated with a NodeId key
     * @param map The NodeIdToBytes32Map to query
     * @param key The NodeId key to look up
     * @return success True if the key exists in the map, false otherwise
     * @return value The bytes32 value if the key exists, zero otherwise
     */
    function tryGet(NodeIdToBytes32Map storage map, NodeId key) internal view returns (bool success, bytes32 value) {
        (success, value) = EnumerableMap.tryGet(map.inner, NodeId.unwrap(key));
    }

    // NodeIdToFairMap

    /**
     * @notice Gets the Fair value associated with a NodeId key
     * @dev Reverts if the key is not in the map
     * @param map The NodeIdToFairMap to query
     * @param key The NodeId key to look up
     * @return value The Fair value associated with the key
     */
    function get(NodeIdToFairMap storage map, NodeId key) internal view returns (Fair value) {
        return Fair.wrap(EnumerableMap.get(map.inner, NodeId.unwrap(key)));
    }

    /**
     * @notice Checks if a NodeId key exists in the map
     * @param map The NodeIdToFairMap to query
     * @param key The NodeId key to check for existence
     * @return result True if the key is in the map, false otherwise
     */
    function contains(NodeIdToFairMap storage map, NodeId key) internal view returns (bool result) {
        result = EnumerableMap.contains(map.inner, NodeId.unwrap(key));
    }

    /**
     * @notice Attempts to get the Fair value associated with a NodeId key
     * @param map The NodeIdToFairMap to query
     * @param key The NodeId key to look up
     * @return success True if the key exists in the map, false otherwise
     * @return value The Fair value if the key exists, wrapped zero otherwise
     */
    function tryGet(NodeIdToFairMap storage map, NodeId key) internal view returns (bool success, Fair value) {
        uint256 rawValue;
        (success, rawValue) = EnumerableMap.tryGet(map.inner, NodeId.unwrap(key));
        value = Fair.wrap(rawValue);
    }

    /**
     * @notice Returns all NodeId keys in the map as an array
     * @param map The NodeIdToFairMap to query
     * @return nodes Array containing all NodeId keys in the map
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
     * @notice Gets the Credit value associated with a Holder key
     * @dev Reverts if the key is not in the map
     * @param map The HolderToCreditMap to query
     * @param key The Holder key to look up
     * @return value The Credit value associated with the key
     */
    function get(HolderToCreditMap storage map, Holder key) internal view returns (Credit value) {
        return Credit.wrap(EnumerableMap.get(map.inner, Holder.unwrap(key)));
    }

    /**
     * @notice Checks if a Holder key exists in the map
     * @param map The HolderToCreditMap to query
     * @param key The Holder key to check for existence
     * @return result True if the key is in the map, false otherwise
     */
    function contains(HolderToCreditMap storage map, Holder key) internal view returns (bool result) {
        result = EnumerableMap.contains(map.inner, Holder.unwrap(key));
    }

    /**
     * @notice Attempts to get the Credit value associated with a Holder key
     * @param map The HolderToCreditMap to query
     * @param key The Holder key to look up
     * @return success True if the key exists in the map, false otherwise
     * @return value The Credit value if the key exists, wrapped zero otherwise
     */
    function tryGet(HolderToCreditMap storage map, Holder key) internal view returns (bool success, Credit value) {
        uint256 rawValue;
        (success, rawValue) = EnumerableMap.tryGet(map.inner, Holder.unwrap(key));
        value = Credit.wrap(rawValue);
    }

    /**
     * @notice Returns all Holder keys in the map as an array
     * @param map The HolderToCreditMap to query
     * @return nodes Array containing all Holder keys in the map
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
     * @notice Returns the number of key-value pairs in the map
     * @param map The HolderToCreditMap to query
     * @return len The number of elements in the map
     */
    function length(HolderToCreditMap storage map) internal view returns (uint256 len) {
        return EnumerableMap.length(map.inner);
    }
}

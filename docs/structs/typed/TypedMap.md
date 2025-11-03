# Solidity API

## TypedMap

Library providing type-safe wrappers around OpenZeppelin's EnumerableMap

**dev:** _Implements strongly-typed maps for NodeId, Fair, Credit, and Holder types
to prevent type confusion and improve code safety and readability._

### AddressToNodeIdMap

Map from addresses to NodeIds with enumeration support

```solidity
struct AddressToNodeIdMap {
  struct EnumerableMap.AddressToUintMap inner;
}
```

### AddressToNodeIdSetMap

Map from addresses to sets of NodeIds

```solidity
struct AddressToNodeIdSetMap {
  mapping(address => struct TypedSet.NodeIdSet) inner;
}
```

### NodeIdToBytes32Map

Map from NodeIds to bytes32 values with enumeration support

```solidity
struct NodeIdToBytes32Map {
  struct EnumerableMap.UintToBytes32Map inner;
}
```

### NodeIdToFairMap

Map from NodeIds to Fair values with enumeration support

```solidity
struct NodeIdToFairMap {
  struct EnumerableMap.UintToUintMap inner;
}
```

### HolderToCreditMap

Map from Holders to Credit values with enumeration support

```solidity
struct HolderToCreditMap {
  struct EnumerableMap.UintToUintMap inner;
}
```

### set

Sets or updates a NodeId for a given address key

```solidity
function set(struct TypedMap.AddressToNodeIdMap map, address key, NodeId value) internal returns (bool added)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| map | struct TypedMap.AddressToNodeIdMap | The AddressToNodeIdMap to modify |
| key | address | The address key |
| value | NodeId | The NodeId value to associate with the key |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| added | bool | True if the key was added (was not already present), false if updated |

### remove

Removes an address key and its associated NodeId from the map

```solidity
function remove(struct TypedMap.AddressToNodeIdMap map, address key) internal returns (bool removed)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| map | struct TypedMap.AddressToNodeIdMap | The AddressToNodeIdMap to modify |
| key | address | The address key to remove |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| removed | bool | True if the key was removed (was present), false otherwise |

### add

Adds a NodeId to the set associated with an address key

```solidity
function add(struct TypedMap.AddressToNodeIdSetMap map, address key, NodeId nodeId) internal returns (bool added)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| map | struct TypedMap.AddressToNodeIdSetMap | The AddressToNodeIdSetMap to modify |
| key | address | The address key |
| nodeId | NodeId | The NodeId to add to the set |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| added | bool | True if the nodeId was added (was not already in the set), false otherwise |

### remove

Removes a NodeId from the set associated with an address key

```solidity
function remove(struct TypedMap.AddressToNodeIdSetMap map, address key, NodeId nodeId) internal returns (bool removed)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| map | struct TypedMap.AddressToNodeIdSetMap | The AddressToNodeIdSetMap to modify |
| key | address | The address key |
| nodeId | NodeId | The NodeId to remove from the set |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| removed | bool | True if the nodeId was removed (was in the set), false otherwise |

### clear

Removes all elements from the map

```solidity
function clear(struct TypedMap.NodeIdToBytes32Map map) internal
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| map | struct TypedMap.NodeIdToBytes32Map | The NodeIdToBytes32Map to clear |

### set

Sets or updates a bytes32 value for a given NodeId key

```solidity
function set(struct TypedMap.NodeIdToBytes32Map map, NodeId key, bytes32 value) internal returns (bool added)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| map | struct TypedMap.NodeIdToBytes32Map | The NodeIdToBytes32Map to modify |
| key | NodeId | The NodeId key |
| value | bytes32 | The bytes32 value to associate with the key |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| added | bool | True if the key was added (was not already present), false if updated |

### set

Sets or updates a Fair value for a given NodeId key

```solidity
function set(struct TypedMap.NodeIdToFairMap map, NodeId key, Fair value) internal returns (bool added)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| map | struct TypedMap.NodeIdToFairMap | The NodeIdToFairMap to modify |
| key | NodeId | The NodeId key |
| value | Fair | The Fair value to associate with the key |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| added | bool | True if the key was added (was not already present), false if updated |

### remove

Removes a NodeId key and its associated Fair value from the map

```solidity
function remove(struct TypedMap.NodeIdToFairMap map, NodeId key) internal returns (bool removed)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| map | struct TypedMap.NodeIdToFairMap | The NodeIdToFairMap to modify |
| key | NodeId | The NodeId key to remove |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| removed | bool | True if the key was removed (was present), false otherwise |

### set

Sets or updates a Credit value for a given Holder key

```solidity
function set(struct TypedMap.HolderToCreditMap map, Holder key, Credit value) internal returns (bool added)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| map | struct TypedMap.HolderToCreditMap | The HolderToCreditMap to modify |
| key | Holder | The Holder key |
| value | Credit | The Credit value to associate with the key |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| added | bool | True if the key was added (was not already present), false if updated |

### remove

Removes a Holder key and its associated Credit value from the map

```solidity
function remove(struct TypedMap.HolderToCreditMap map, Holder key) internal returns (bool removed)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| map | struct TypedMap.HolderToCreditMap | The HolderToCreditMap to modify |
| key | Holder | The Holder key to remove |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| removed | bool | True if the key was removed (was present), false otherwise |

### contains

Checks if an address key exists in the map

```solidity
function contains(struct TypedMap.AddressToNodeIdMap map, address key) internal view returns (bool result)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| map | struct TypedMap.AddressToNodeIdMap | The AddressToNodeIdMap to query |
| key | address | The address key to check for existence |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | bool | True if the key is in the map, false otherwise |

### length

Returns the number of key-value pairs in the map

```solidity
function length(struct TypedMap.AddressToNodeIdMap map) internal view returns (uint256 len)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| map | struct TypedMap.AddressToNodeIdMap | The AddressToNodeIdMap to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| len | uint256 | The number of elements in the map |

### get

Gets the NodeId value associated with an address key

```solidity
function get(struct TypedMap.AddressToNodeIdMap map, address key) internal view returns (NodeId nodeId)
```

**dev:** _Reverts if the key is not in the map_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| map | struct TypedMap.AddressToNodeIdMap | The AddressToNodeIdMap to query |
| key | address | The address key to look up |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The NodeId value associated with the key |

### tryGet

Attempts to get the NodeId value associated with an address key

```solidity
function tryGet(struct TypedMap.AddressToNodeIdMap map, address key) internal view returns (bool success, NodeId nodeId)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| map | struct TypedMap.AddressToNodeIdMap | The AddressToNodeIdMap to query |
| key | address | The address key to look up |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| success | bool | True if the key exists in the map, false otherwise |
| nodeId | NodeId | The NodeId value if the key exists, wrapped zero otherwise |

### lengthOf

Returns the number of NodeIds in the set associated with an address key

```solidity
function lengthOf(struct TypedMap.AddressToNodeIdSetMap map, address key) internal view returns (uint256 len)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| map | struct TypedMap.AddressToNodeIdSetMap | The AddressToNodeIdSetMap to query |
| key | address | The address key |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| len | uint256 | The number of NodeIds in the set |

### getValuesAt

Gets all NodeIds in the set associated with an address key

```solidity
function getValuesAt(struct TypedMap.AddressToNodeIdSetMap map, address key) internal view returns (NodeId[] ids)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| map | struct TypedMap.AddressToNodeIdSetMap | The AddressToNodeIdSetMap to query |
| key | address | The address key |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| ids | NodeId[] | Array containing all NodeIds in the set |

### isSet

Checks if a NodeId exists in the set associated with an address key

```solidity
function isSet(struct TypedMap.AddressToNodeIdSetMap map, address key, NodeId nodeId) internal view returns (bool result)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| map | struct TypedMap.AddressToNodeIdSetMap | The AddressToNodeIdSetMap to query |
| key | address | The address key |
| nodeId | NodeId | The NodeId to check for existence |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | bool | True if the nodeId is in the set, false otherwise |

### contains

Checks if a NodeId key exists in the map

```solidity
function contains(struct TypedMap.NodeIdToBytes32Map map, NodeId key) internal view returns (bool result)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| map | struct TypedMap.NodeIdToBytes32Map | The NodeIdToBytes32Map to query |
| key | NodeId | The NodeId key to check for existence |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | bool | True if the key is in the map, false otherwise |

### length

Returns the number of key-value pairs in the map

```solidity
function length(struct TypedMap.NodeIdToBytes32Map map) internal view returns (uint256 len)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| map | struct TypedMap.NodeIdToBytes32Map | The NodeIdToBytes32Map to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| len | uint256 | The number of elements in the map |

### tryGet

Attempts to get the bytes32 value associated with a NodeId key

```solidity
function tryGet(struct TypedMap.NodeIdToBytes32Map map, NodeId key) internal view returns (bool success, bytes32 value)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| map | struct TypedMap.NodeIdToBytes32Map | The NodeIdToBytes32Map to query |
| key | NodeId | The NodeId key to look up |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| success | bool | True if the key exists in the map, false otherwise |
| value | bytes32 | The bytes32 value if the key exists, zero otherwise |

### get

Gets the Fair value associated with a NodeId key

```solidity
function get(struct TypedMap.NodeIdToFairMap map, NodeId key) internal view returns (Fair value)
```

**dev:** _Reverts if the key is not in the map_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| map | struct TypedMap.NodeIdToFairMap | The NodeIdToFairMap to query |
| key | NodeId | The NodeId key to look up |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| value | Fair | The Fair value associated with the key |

### contains

Checks if a NodeId key exists in the map

```solidity
function contains(struct TypedMap.NodeIdToFairMap map, NodeId key) internal view returns (bool result)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| map | struct TypedMap.NodeIdToFairMap | The NodeIdToFairMap to query |
| key | NodeId | The NodeId key to check for existence |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | bool | True if the key is in the map, false otherwise |

### tryGet

Attempts to get the Fair value associated with a NodeId key

```solidity
function tryGet(struct TypedMap.NodeIdToFairMap map, NodeId key) internal view returns (bool success, Fair value)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| map | struct TypedMap.NodeIdToFairMap | The NodeIdToFairMap to query |
| key | NodeId | The NodeId key to look up |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| success | bool | True if the key exists in the map, false otherwise |
| value | Fair | The Fair value if the key exists, wrapped zero otherwise |

### keys

Returns all NodeId keys in the map as an array

```solidity
function keys(struct TypedMap.NodeIdToFairMap map) internal view returns (NodeId[] nodes)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| map | struct TypedMap.NodeIdToFairMap | The NodeIdToFairMap to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodes | NodeId[] | Array containing all NodeId keys in the map |

### get

Gets the Credit value associated with a Holder key

```solidity
function get(struct TypedMap.HolderToCreditMap map, Holder key) internal view returns (Credit value)
```

**dev:** _Reverts if the key is not in the map_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| map | struct TypedMap.HolderToCreditMap | The HolderToCreditMap to query |
| key | Holder | The Holder key to look up |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| value | Credit | The Credit value associated with the key |

### contains

Checks if a Holder key exists in the map

```solidity
function contains(struct TypedMap.HolderToCreditMap map, Holder key) internal view returns (bool result)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| map | struct TypedMap.HolderToCreditMap | The HolderToCreditMap to query |
| key | Holder | The Holder key to check for existence |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | bool | True if the key is in the map, false otherwise |

### tryGet

Attempts to get the Credit value associated with a Holder key

```solidity
function tryGet(struct TypedMap.HolderToCreditMap map, Holder key) internal view returns (bool success, Credit value)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| map | struct TypedMap.HolderToCreditMap | The HolderToCreditMap to query |
| key | Holder | The Holder key to look up |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| success | bool | True if the key exists in the map, false otherwise |
| value | Credit | The Credit value if the key exists, wrapped zero otherwise |

### keys

Returns all Holder keys in the map as an array

```solidity
function keys(struct TypedMap.HolderToCreditMap map) internal view returns (Holder[] nodes)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| map | struct TypedMap.HolderToCreditMap | The HolderToCreditMap to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodes | Holder[] | Array containing all Holder keys in the map |

### length

Returns the number of key-value pairs in the map

```solidity
function length(struct TypedMap.HolderToCreditMap map) internal view returns (uint256 len)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| map | struct TypedMap.HolderToCreditMap | The HolderToCreditMap to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| len | uint256 | The number of elements in the map |


# Solidity API

## TypedSet

Library providing type-safe wrappers around OpenZeppelin's EnumerableSet

**dev:** _Implements strongly-typed sets for NodeId to prevent type confusion and improve code safety and readability._

### NodeIdSet

Set of NodeIds with enumeration support

```solidity
struct NodeIdSet {
  struct EnumerableSet.UintSet inner;
}
```

### add

Adds a NodeId to the set

```solidity
function add(struct TypedSet.NodeIdSet set, NodeId nodeId) internal returns (bool added)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| set | struct TypedSet.NodeIdSet | The NodeIdSet to modify |
| nodeId | NodeId | The NodeId to add to the set |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| added | bool | True if the nodeId was added (was not already present), false otherwise |

### clear

Removes all elements from the set

```solidity
function clear(struct TypedSet.NodeIdSet set) internal
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| set | struct TypedSet.NodeIdSet | The NodeIdSet to clear |

### remove

Removes a NodeId from the set

```solidity
function remove(struct TypedSet.NodeIdSet set, NodeId nodeId) internal returns (bool removed)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| set | struct TypedSet.NodeIdSet | The NodeIdSet to modify |
| nodeId | NodeId | The NodeId to remove from the set |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| removed | bool | True if the nodeId was removed (was present), false otherwise |

### contains

Checks if a NodeId exists in the set

```solidity
function contains(struct TypedSet.NodeIdSet set, NodeId nodeId) internal view returns (bool exists)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| set | struct TypedSet.NodeIdSet | The NodeIdSet to query |
| nodeId | NodeId | The NodeId to check for existence |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| exists | bool | True if the nodeId is in the set, false otherwise |

### length

Returns the number of NodeIds in the set

```solidity
function length(struct TypedSet.NodeIdSet set) internal view returns (uint256 len)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| set | struct TypedSet.NodeIdSet | The NodeIdSet to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| len | uint256 | The number of elements in the set |

### values

Returns all NodeIds in the set as an array

```solidity
function values(struct TypedSet.NodeIdSet set) internal view returns (NodeId[] nodeIds)
```

**dev:** _Order is not guaranteed and may change when adding/removing elements_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| set | struct TypedSet.NodeIdSet | The NodeIdSet to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeIds | NodeId[] | Array containing all NodeIds in the set |

### at

Returns the NodeId at a specific index in the set

```solidity
function at(struct TypedSet.NodeIdSet set, uint256 index) internal view returns (NodeId nodeId)
```

**dev:** _Reverts if index is out of bounds_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| set | struct TypedSet.NodeIdSet | The NodeIdSet to query |
| index | uint256 | The zero-based index of the element to retrieve |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The NodeId at the specified index |


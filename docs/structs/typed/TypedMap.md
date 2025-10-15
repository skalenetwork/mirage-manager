# Solidity API

## TypedMap

_Library providing type-safe wrappers around OpenZeppelin's EnumerableMap
Implements strongly-typed maps for NodeId, Fair, Credit, and Holder types
to prevent type confusion and improve code safety and readability._

### AddressToNodeIdMap

```solidity
struct AddressToNodeIdMap {
  struct EnumerableMap.AddressToUintMap inner;
}
```

### AddressToNodeIdSetMap

```solidity
struct AddressToNodeIdSetMap {
  mapping(address => struct TypedSet.NodeIdSet) inner;
}
```

### NodeIdToBytes32Map

```solidity
struct NodeIdToBytes32Map {
  struct EnumerableMap.UintToBytes32Map inner;
}
```

### NodeIdToFairMap

```solidity
struct NodeIdToFairMap {
  struct EnumerableMap.UintToUintMap inner;
}
```

### HolderToCreditMap

```solidity
struct HolderToCreditMap {
  struct EnumerableMap.UintToUintMap inner;
}
```

### set

```solidity
function set(struct TypedMap.AddressToNodeIdMap map, address key, NodeId value) internal returns (bool added)
```

### remove

```solidity
function remove(struct TypedMap.AddressToNodeIdMap map, address key) internal returns (bool removed)
```

### add

```solidity
function add(struct TypedMap.AddressToNodeIdSetMap map, address key, NodeId nodeId) internal returns (bool added)
```

### remove

```solidity
function remove(struct TypedMap.AddressToNodeIdSetMap map, address key, NodeId nodeId) internal returns (bool removed)
```

### clear

```solidity
function clear(struct TypedMap.NodeIdToBytes32Map map) internal
```

### set

```solidity
function set(struct TypedMap.NodeIdToBytes32Map map, NodeId key, bytes32 value) internal returns (bool added)
```

### set

```solidity
function set(struct TypedMap.NodeIdToFairMap map, NodeId key, Fair value) internal returns (bool added)
```

### remove

```solidity
function remove(struct TypedMap.NodeIdToFairMap map, NodeId key) internal returns (bool removed)
```

### set

```solidity
function set(struct TypedMap.HolderToCreditMap map, Holder key, Credit value) internal returns (bool added)
```

### remove

```solidity
function remove(struct TypedMap.HolderToCreditMap map, Holder key) internal returns (bool removed)
```

### contains

```solidity
function contains(struct TypedMap.AddressToNodeIdMap map, address key) internal view returns (bool result)
```

### length

```solidity
function length(struct TypedMap.AddressToNodeIdMap map) internal view returns (uint256 len)
```

### get

```solidity
function get(struct TypedMap.AddressToNodeIdMap map, address key) internal view returns (NodeId nodeId)
```

### tryGet

```solidity
function tryGet(struct TypedMap.AddressToNodeIdMap map, address key) internal view returns (bool success, NodeId nodeId)
```

### lengthOf

```solidity
function lengthOf(struct TypedMap.AddressToNodeIdSetMap map, address key) internal view returns (uint256 len)
```

### getValuesAt

```solidity
function getValuesAt(struct TypedMap.AddressToNodeIdSetMap map, address key) internal view returns (NodeId[] ids)
```

### isSet

```solidity
function isSet(struct TypedMap.AddressToNodeIdSetMap map, address key, NodeId nodeId) internal view returns (bool result)
```

### contains

```solidity
function contains(struct TypedMap.NodeIdToBytes32Map map, NodeId key) internal view returns (bool result)
```

### length

```solidity
function length(struct TypedMap.NodeIdToBytes32Map map) internal view returns (uint256 len)
```

### tryGet

```solidity
function tryGet(struct TypedMap.NodeIdToBytes32Map map, NodeId key) internal view returns (bool success, bytes32 value)
```

### get

```solidity
function get(struct TypedMap.NodeIdToFairMap map, NodeId key) internal view returns (Fair value)
```

### contains

```solidity
function contains(struct TypedMap.NodeIdToFairMap map, NodeId key) internal view returns (bool result)
```

### tryGet

```solidity
function tryGet(struct TypedMap.NodeIdToFairMap map, NodeId key) internal view returns (bool success, Fair value)
```

### keys

```solidity
function keys(struct TypedMap.NodeIdToFairMap map) internal view returns (NodeId[] nodes)
```

### get

```solidity
function get(struct TypedMap.HolderToCreditMap map, Holder key) internal view returns (Credit value)
```

### contains

```solidity
function contains(struct TypedMap.HolderToCreditMap map, Holder key) internal view returns (bool result)
```

### tryGet

```solidity
function tryGet(struct TypedMap.HolderToCreditMap map, Holder key) internal view returns (bool success, Credit value)
```

### keys

```solidity
function keys(struct TypedMap.HolderToCreditMap map) internal view returns (Holder[] nodes)
```

### length

```solidity
function length(struct TypedMap.HolderToCreditMap map) internal view returns (uint256 len)
```


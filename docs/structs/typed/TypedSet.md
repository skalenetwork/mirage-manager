# Solidity API

## TypedSet

_Library providing type-safe wrappers around OpenZeppelin's EnumerableSet
Implements strongly-typed sets for NodeId to prevent type confusion and improve code safety and readability._

### NodeIdSet

_Set of NodeIds with enumeration support_

```solidity
struct NodeIdSet {
  struct EnumerableSet.UintSet inner;
}
```

### add

```solidity
function add(struct TypedSet.NodeIdSet set, NodeId nodeId) internal returns (bool added)
```

_Adds a NodeId to the set_

### clear

```solidity
function clear(struct TypedSet.NodeIdSet set) internal
```

_Removes all elements from the set_

### remove

```solidity
function remove(struct TypedSet.NodeIdSet set, NodeId nodeId) internal returns (bool removed)
```

_Removes a NodeId from the set_

### contains

```solidity
function contains(struct TypedSet.NodeIdSet set, NodeId nodeId) internal view returns (bool exists)
```

_Checks if a NodeId exists in the set_

### length

```solidity
function length(struct TypedSet.NodeIdSet set) internal view returns (uint256 len)
```

_Returns the number of NodeIds in the set_

### values

```solidity
function values(struct TypedSet.NodeIdSet set) internal view returns (NodeId[] nodeIds)
```

_Returns all NodeIds in the set as an array_

### at

```solidity
function at(struct TypedSet.NodeIdSet set, uint256 index) internal view returns (NodeId nodeId)
```

_Returns the NodeId at a specific index in the set_


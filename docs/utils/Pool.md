# Solidity API

## PoolLibrary

Library for managing a pool of nodes for committee selection

_Implements a two-tier pool structure: present nodes (in red-black tree) and incoming nodes (waiting heartbeat).
Uses weighted random sampling to select committee members fairly based on staking amounts._

### Pool

_Pool data structure with weighted tree and incoming nodes_

```solidity
struct Pool {
  mapping(NodeId => struct RedBlackTree.Node) tree;
  NodeId root;
  struct TypedSet.NodeIdSet presentNodes;
  struct TypedSet.NodeIdSet incomingNodes;
  contract IStatus status;
}
```

### TooFewCandidates

```solidity
error TooFewCandidates(uint256 needed, uint256 available)
```

_Not enough healthy node candidates available for selection_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| needed | uint256 | The number of nodes needed |
| available | uint256 | The number of nodes available |

### add

```solidity
function add(struct PoolLibrary.Pool pool, NodeId id) internal
```

_Adds a node to the incoming pool (waiting heartbeat)
Should not be called if the node is already present in the tree_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| pool | struct PoolLibrary.Pool | The pool storage |
| id | NodeId | The node ID to add |

### moveToFront

```solidity
function moveToFront(struct PoolLibrary.Pool pool, NodeId node, uint256 weight) internal
```

_Moves a node to the front (leftmost position) of the weighted tree
Removes the node if present, then inserts it with given weight_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| pool | struct PoolLibrary.Pool | The pool storage |
| node | NodeId | The node ID to move |
| weight | uint256 | The weight value for the node |

### remove

```solidity
function remove(struct PoolLibrary.Pool pool, NodeId node) internal returns (bool removed)
```

_Removes a node from the pool (either present or incoming)
Removes from the weighted tree if present, otherwise from incoming set_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| pool | struct PoolLibrary.Pool | The pool storage |
| node | NodeId | The node ID to remove |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| removed | bool | True if the node was removed |

### sample

```solidity
function sample(struct PoolLibrary.Pool pool, uint256 size, struct IRandom.RandomGenerator generator) internal returns (NodeId[] nodesSample)
```

_Performs weighted random sampling to select nodes from the pool
Only samples from healthy nodes. Selected nodes are moved to incoming set (require heartbeat for next selection).
Uses cumulative weight-based selection for fairness._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| pool | struct PoolLibrary.Pool | The pool storage |
| size | uint256 | The number of nodes to sample |
| generator | struct IRandom.RandomGenerator | The random number generator instance |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodesSample | NodeId[] | Array of selected node IDs |

### setWeight

```solidity
function setWeight(struct PoolLibrary.Pool pool, NodeId node, uint256 weight) internal
```

_Updates the weight of a node in the pool
Only updates weight if the node is in the present node's pool, otherwise irrelevant_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| pool | struct PoolLibrary.Pool | The pool storage |
| node | NodeId | The node ID to update |
| weight | uint256 | The new weight value |

### getOldestIsh

```solidity
function getOldestIsh(struct PoolLibrary.Pool pool) internal view returns (NodeId oldest)
```

_Gets an approximate oldest node from the pool
Returns first incoming node if any, otherwise the rightmost (oldest) node in tree_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| pool | struct PoolLibrary.Pool | The pool storage |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| oldest | NodeId | The oldest-ish node ID, or NULL if pool is empty |

### contains

```solidity
function contains(struct PoolLibrary.Pool pool, NodeId node) internal view returns (bool present)
```

_Checks if a node is in the pool
Searches both the active tree and incoming set_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| pool | struct PoolLibrary.Pool | The pool storage |
| node | NodeId | The node ID to check |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| present | bool | True if the node is in the pool |

### length

```solidity
function length(struct PoolLibrary.Pool pool) internal view returns (uint256 poolSize)
```

_Returns the total number of nodes in the pool
Sums present nodes and incoming nodes_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| pool | struct PoolLibrary.Pool | The pool storage |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| poolSize | uint256 | The total number of nodes |


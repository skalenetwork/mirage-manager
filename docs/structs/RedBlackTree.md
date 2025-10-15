# Solidity API

## RedBlackTree

_Library implementing a weighted red-black tree for efficient node selection
Maintains tree balancing properties while tracking cumulative weights for weighted
random sampling. Used by the eligible pool for committee selection._

### Node

_Red-black tree node structure_

```solidity
struct Node {
  NodeId id;
  NodeId parent;
  NodeId left;
  NodeId right;
  uint248 totalWeight;
  bool red;
}
```

### NULL

```solidity
NodeId NULL
```

### ChildIsMissing

```solidity
error ChildIsMissing(NodeId node, NodeId child)
```

### InsertNullNode

```solidity
error InsertNullNode()
```

### NotFound

```solidity
error NotFound()
```

### RemoveNullNode

```solidity
error RemoveNullNode()
```

### SetWeightOfNullNode

```solidity
error SetWeightOfNullNode()
```

### insertSmallest

```solidity
function insertSmallest(mapping(NodeId => struct RedBlackTree.Node) nodes, NodeId root, NodeId newNode, uint256 weight) internal returns (NodeId newRoot)
```

_Inserts a new node as the smallest (leftmost) element in the tree_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodes | mapping(NodeId &#x3D;&gt; struct RedBlackTree.Node) | The tree storage mapping |
| root | NodeId | The current root node |
| newNode | NodeId | The node ID to insert |
| weight | uint256 | The weight value for the new node |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| newRoot | NodeId | The root after insertion and rebalancing |

### remove

```solidity
function remove(mapping(NodeId => struct RedBlackTree.Node) nodes, NodeId root, NodeId node) internal returns (NodeId newRoot)
```

_Removes a node from the tree and re-balances_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodes | mapping(NodeId &#x3D;&gt; struct RedBlackTree.Node) | The tree storage mapping |
| root | NodeId | The current root node |
| node | NodeId | The node ID to remove |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| newRoot | NodeId | The root after removal and rebalancing |

### setWeight

```solidity
function setWeight(mapping(NodeId => struct RedBlackTree.Node) nodes, NodeId node, uint256 weight) internal
```

_Updates the weight of a node and propagates changes up the tree_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodes | mapping(NodeId &#x3D;&gt; struct RedBlackTree.Node) | The tree storage mapping |
| node | NodeId | The node ID to update |
| weight | uint256 | The new weight value |

### findByWeight

```solidity
function findByWeight(mapping(NodeId => struct RedBlackTree.Node) nodes, NodeId root, uint256 weight) internal view returns (NodeId node)
```

_Finds a node by cumulative weight for weighted random sampling_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodes | mapping(NodeId &#x3D;&gt; struct RedBlackTree.Node) | The tree storage mapping |
| root | NodeId | The root node |
| weight | uint256 | The target cumulative weight |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node ID at the specified weight position |

### findLast

```solidity
function findLast(mapping(NodeId => struct RedBlackTree.Node) nodes, NodeId root) internal view returns (NodeId biggest)
```

_Finds the rightmost node in the subtree_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodes | mapping(NodeId &#x3D;&gt; struct RedBlackTree.Node) | The tree storage mapping |
| root | NodeId | The root of the subtree to search |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| biggest | NodeId | The rightmost node ID |

### getWeight

```solidity
function getWeight(mapping(NodeId => struct RedBlackTree.Node) nodes, NodeId node) internal view returns (uint248 weight)
```

_Gets the weight of a specific node (excluding subtree weights)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodes | mapping(NodeId &#x3D;&gt; struct RedBlackTree.Node) | The tree storage mapping |
| node | NodeId | The node ID to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| weight | uint248 | The node's individual weight |

### getWeightTill

```solidity
function getWeightTill(mapping(NodeId => struct RedBlackTree.Node) nodes, NodeId bound) internal view returns (uint256 weight)
```

_Calculates cumulative weight up to and including a specific node_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodes | mapping(NodeId &#x3D;&gt; struct RedBlackTree.Node) | The tree storage mapping |
| bound | NodeId | The node to calculate weight till |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| weight | uint256 | The cumulative weight from the leftmost node to bound |


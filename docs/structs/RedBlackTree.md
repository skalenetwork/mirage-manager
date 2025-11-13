# Solidity API

## RedBlackTree

Data structure (Red Black Tree) library for efficient weighted node management

**dev:** _Implements a weighted red-black tree for efficient node selection
Maintains tree balancing properties while tracking cumulative weights for weighted
random sampling.
The tree uses an implicit key for sorting - node's last heartbeat timestamp.
Used by the pool to maintain eligible nodes for committee selection._

### Node

Red-black tree node structure

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

Sentinel value representing a null node

```solidity
NodeId NULL
```

### ChildIsMissing

```solidity
error ChildIsMissing(NodeId node, NodeId child)
```

**dev:** _Error indicating a child node is missing when expected_

### InsertNullNode

```solidity
error InsertNullNode()
```

**dev:** _Error indicating an attempt to insert a null node_

### NotFound

```solidity
error NotFound()
```

**dev:** _Error indicating a node was not found in the tree_

### RemoveNullNode

```solidity
error RemoveNullNode()
```

**dev:** _Error indicating an attempt to remove a null node_

### SetWeightOfNullNode

```solidity
error SetWeightOfNullNode()
```

**dev:** _Error indicating an attempt to set weight of a null node_

### insertSmallest

Inserts a new node as the smallest (leftmost) element in the tree

```solidity
function insertSmallest(mapping(NodeId => struct RedBlackTree.Node) nodes, NodeId root, NodeId newNode, uint256 weight) internal returns (NodeId newRoot)
```

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

Removes a node from the tree and re-balances

```solidity
function remove(mapping(NodeId => struct RedBlackTree.Node) nodes, NodeId root, NodeId node) internal returns (NodeId newRoot)
```

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

Updates the weight of a node and propagates changes up the tree

```solidity
function setWeight(mapping(NodeId => struct RedBlackTree.Node) nodes, NodeId node, uint256 weight) internal
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodes | mapping(NodeId &#x3D;&gt; struct RedBlackTree.Node) | The tree storage mapping |
| node | NodeId | The node ID to update |
| weight | uint256 | The new weight value |

### findByWeight

Finds a node by cumulative weight for weighted random sampling

```solidity
function findByWeight(mapping(NodeId => struct RedBlackTree.Node) nodes, NodeId root, uint256 weight) internal view returns (NodeId node)
```

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

Finds the rightmost node in the subtree

```solidity
function findLast(mapping(NodeId => struct RedBlackTree.Node) nodes, NodeId root) internal view returns (NodeId biggest)
```

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

Gets the weight of a specific node (excluding subtree weights)

```solidity
function getWeight(mapping(NodeId => struct RedBlackTree.Node) nodes, NodeId node) internal view returns (uint248 weight)
```

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

Calculates cumulative weight up to and including a specific node

```solidity
function getWeightTill(mapping(NodeId => struct RedBlackTree.Node) nodes, NodeId bound) internal view returns (uint256 weight)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodes | mapping(NodeId &#x3D;&gt; struct RedBlackTree.Node) | The tree storage mapping |
| bound | NodeId | The node to calculate weight till |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| weight | uint256 | The cumulative weight from the leftmost node to bound |


# Solidity API

## Nodes

Manages node registration, configuration, and lifecycle in the FAIR network

_Handles both active nodes (participate in consensus) and passive nodes (indexers, archival, etc.)_

### NodeInfo

Helper structure to store additional node information

```solidity
struct NodeInfo {
  bytes32[2] publicKey;
}
```

### ZERO_IPV4

```solidity
bytes4 ZERO_IPV4
```

Zero IPv4 address constant used for validation

### ZERO_IPV6

```solidity
bytes16 ZERO_IPV6
```

Zero IPv6 address constant used for validation

### nodes

```solidity
mapping(NodeId => struct INodes.Node) nodes
```

Mapping from node ID to Node struct

### ownerChangeRequests

```solidity
mapping(NodeId => address) ownerChangeRequests
```

Stores pending requests to change node ownership

### committeeContract

```solidity
contract ICommittee committeeContract
```

Reference to the Committee contract

### CommitteeUpdated

```solidity
event CommitteeUpdated(contract ICommittee newCommittee)
```

Emitted when the Committee contract reference is updated

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| newCommittee | contract ICommittee | The new Committee contract address |

### NodeIsInCommittee

```solidity
error NodeIsInCommittee(NodeId nodeId)
```

Thrown when attempting to modify a node that is in the committee

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node in the committee |

### AddressWasAlreadyAssignedToNode

```solidity
error AddressWasAlreadyAssignedToNode(address nodeAddress)
```

Thrown when an address is already assigned to a node

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeAddress | address | The address that is already assigned |

### AddressIsNotAssignedToAnyNode

```solidity
error AddressIsNotAssignedToAnyNode(address nodeAddress)
```

Thrown when an address is not assigned to any node

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeAddress | address | The address that is not assigned |

### PassiveNodeAlreadyExistsForAddress

```solidity
error PassiveNodeAlreadyExistsForAddress(address nodeAddress, NodeId nodeId)
```

Thrown when a passive node already exists for an address

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeAddress | address | The address with an existing passive node |
| nodeId | NodeId | The ID of the existing passive node |

### AddressInUseByPassiveNodes

```solidity
error AddressInUseByPassiveNodes(address nodeAddress)
```

Thrown when an address is in use by passive nodes

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeAddress | address | The address in use |

### InvalidPublicKey

```solidity
error InvalidPublicKey(bytes32[2] publicKey)
```

Thrown when an invalid public key is provided

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| publicKey | bytes32[2] | The invalid public key |

### InvalidPublicKeyForSender

```solidity
error InvalidPublicKeyForSender(bytes32[2] publicKey, address expected, address sender)
```

Thrown when the public key doesn't match the sender

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| publicKey | bytes32[2] | The provided public key |
| expected | address | The expected address derived from the public key |
| sender | address | The actual sender address |

### ActiveNodesCannotChangeOwnership

```solidity
error ActiveNodesCannotChangeOwnership()
```

Thrown when attempting to change ownership of an active node

### InvalidIp

```solidity
error InvalidIp(bytes ip)
```

Thrown when an invalid IP address is provided

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| ip | bytes | The invalid IP address |

### ActiveNodeWasNeverRegistered

```solidity
error ActiveNodeWasNeverRegistered(NodeId nodeId)
```

Thrown when requesting public key for a node that was never registered as active

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node |

### PortShouldNotBeZero

```solidity
error PortShouldNotBeZero()
```

Thrown when port is set to zero

### SenderIsNotNodeOwner

```solidity
error SenderIsNotNodeOwner()
```

Thrown when sender is not the node owner

### SenderIsNotNewNodeOwner

```solidity
error SenderIsNotNewNodeOwner()
```

Thrown when sender is not the new node owner in ownership transfer

### InvalidNodeId

```solidity
error InvalidNodeId(NodeId nodeId, uint256 nodeIdCounter)
```

Thrown when an invalid node ID is provided

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The invalid node ID |
| nodeIdCounter | uint256 | The current node ID counter |

### nodeNotInCurrentOrNextCommittee

```solidity
modifier nodeNotInCurrentOrNextCommittee(NodeId nodeId)
```

_Ensures that the node is not in the current or next committee_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The node ID to check |

### nodeExists

```solidity
modifier nodeExists(NodeId nodeId)
```

_Ensures that the node exists (either active or passive)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The node ID to check |

### validIp

```solidity
modifier validIp(bytes ip)
```

_Validates that the IP address is not zero (for IPv4 or IPv6)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| ip | bytes | The IP address to validate |

### validPort

```solidity
modifier validPort(uint16 port)
```

_Validates that a port number is not zero_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| port | uint16 | The port to validate |

### validPubKey

```solidity
modifier validPubKey(bytes32[2] publicKey)
```

_Validates that the public key is not zero_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| publicKey | bytes32[2] | The public key to validate |

### onlyNodeOwner

```solidity
modifier onlyNodeOwner(NodeId nodeId)
```

_Ensures that the caller is the owner of the specified node_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The node ID to check ownership for |

### initialize

```solidity
function initialize(address initialAuthority, struct INodes.Node[] initialNodes, bytes32[2][] nodesPublicKeys) external
```

Initializes the Nodes contract

_This function is called only once during contract deployment following the proxy pattern_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| initialAuthority | address | The address of the initial access control authority |
| initialNodes | struct INodes.Node[] | Array of initial nodes to register |
| nodesPublicKeys | bytes32[2][] | Array of public keys corresponding to initial nodes |

### setCommittee

```solidity
function setCommittee(contract ICommittee committeeAddress) external
```

Sets the Committee contract address

_Only callable by authorized addresses (restricted)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| committeeAddress | contract ICommittee | The address of the Committee contract |

### registerNode

```solidity
function registerNode(bytes ip, bytes32[2] publicKey, uint16 port) external payable
```

Registers a new active node

_Validates IP, port, and public key, then creates the node as disabled (in staking) by default
The sender must match the address derived from the public key
Can include initial stake via msg.value (should be more than minimum required)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| ip | bytes | The IP address of the node (IPv4 or IPv6) |
| publicKey | bytes32[2] | The node's public key |
| port | uint16 | The port number the node listens on |

### deleteNode

```solidity
function deleteNode(NodeId nodeId) external
```

Deletes a node owned by the caller

_Only callable by the node owner
Node must not be in current or next committee_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node to delete |

### deleteNodeByFoundation

```solidity
function deleteNodeByFoundation(NodeId nodeId) external
```

Deletes a node — restricted to the foundation

_Node must not be in the current or next committee_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node to delete |

### requestChangeOwner

```solidity
function requestChangeOwner(NodeId nodeId, address newOwner) external
```

Requests to change the owner of a passive node

_Only callable by the current node owner
Only works for passive nodes (active nodes cannot change ownership)
New owner must not already own an active node_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node |
| newOwner | address | The address of the new owner |

### confirmOwnerChange

```solidity
function confirmOwnerChange(NodeId nodeId) external
```

Confirms a pending ownership change for a passive node

_Only callable by the new owner specified in the ownership change request
Only works for passive nodes_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node |

### registerPassiveNode

```solidity
function registerPassiveNode(bytes ip, uint16 port) external
```

Registers a new passive node

_Passive nodes don't participate in consensus
Multiple passive nodes can be registered per address_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| ip | bytes | The IP address of the node (IPv4 or IPv6) |
| port | uint16 | The port number the node listens on |

### setIpAddress

```solidity
function setIpAddress(NodeId nodeId, bytes ip, uint16 port) external
```

Sets the IP address and port for a node

_Only callable by the node owner
Node must not be in the current or next committee_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node |
| ip | bytes | The new IP address (IPv4 or IPv6) |
| port | uint16 | The new port number |

### setDomainName

```solidity
function setDomainName(NodeId nodeId, string name) external
```

Sets the domain name for a node

_Only callable by the node owner
Node must not be in the current or next committee_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node |
| name | string | The domain name to set |

### getNode

```solidity
function getNode(NodeId nodeId) external view returns (struct INodes.Node node)
```

Gets the node information for a specific node ID

_Reverts if the node doesn't exist_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | struct INodes.Node | The node information |

### getNodeId

```solidity
function getNodeId(address nodeAddress) external view returns (NodeId nodeId)
```

Gets the node ID for an active node address

_Reverts if the address is not assigned to any active node_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeAddress | address | The address to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The node ID associated with the address |

### getPassiveNodeIdsForAddress

```solidity
function getPassiveNodeIdsForAddress(address nodeAddress) external view returns (NodeId[] nodeIds)
```

Gets all passive node IDs for a specific address

_Reverts if the address has no passive nodes_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeAddress | address | The address to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeIds | NodeId[] | Array of passive node IDs associated with the address |

### getPassiveNodeIds

```solidity
function getPassiveNodeIds() external view returns (NodeId[] nodeIds)
```

Gets all passive node IDs in the system

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeIds | NodeId[] | Array of all passive node IDs |

### getPublicKey

```solidity
function getPublicKey(NodeId nodeId) external view returns (bytes32[2] publicKey)
```

Gets the public key for an active node

_Reverts if the node was never registered as an active node_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| publicKey | bytes32[2] | The node's public key |

### getActiveNodeIds

```solidity
function getActiveNodeIds() external view returns (NodeId[] nodeIds)
```

Gets all active node IDs in the system

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeIds | NodeId[] | Array of all active node IDs |

### activeNodeExists

```solidity
function activeNodeExists(NodeId nodeId) external view returns (bool result)
```

Checks if an active node exists

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node to check |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | bool | True if the node exists and is active, false otherwise |

### passiveNodeExists

```solidity
function passiveNodeExists(NodeId nodeId) external view returns (bool result)
```

Checks if a passive node exists

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node to check |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | bool | True if the node exists and is passive, false otherwise |

### _createActiveNode

```solidity
function _createActiveNode(NodeId nodeId, address nodeAddress, bytes ip, uint16 port, string domainName, bytes32[2] publicKey) internal
```

Creates an active node with the specified parameters

_Internal function called during node registration_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID to assign to the new node |
| nodeAddress | address | The owner address of the node |
| ip | bytes | The IP address of the node |
| port | uint16 | The port number |
| domainName | string | The domain name (can be empty) |
| publicKey | bytes32[2] | The node's public key |


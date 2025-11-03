# Solidity API

## Nodes

Manages node registration, configuration, and lifecycle in the FAIR network

**dev:** _Handles both active nodes (participate in consensus) and passive nodes (indexers, archival, etc.)_

### NodeInfo

Helper structure to store additional node information

```solidity
struct NodeInfo {
  bytes32[2] publicKey;
}
```

### ZERO_IPV4

Zero IPv4 address constant used for validation

```solidity
bytes4 ZERO_IPV4
```

### ZERO_IPV6

Zero IPv6 address constant used for validation

```solidity
bytes16 ZERO_IPV6
```

### nodes

Mapping from node ID to Node struct

```solidity
mapping(NodeId => struct INodes.Node) nodes
```

### ownerChangeRequests

Stores pending requests to change node ownership

```solidity
mapping(NodeId => address) ownerChangeRequests
```

### committeeContract

Reference to the Committee contract

```solidity
contract ICommittee committeeContract
```

### CommitteeUpdated

Emitted when the Committee contract reference is updated

```solidity
event CommitteeUpdated(contract ICommittee newCommittee)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| newCommittee | contract ICommittee | The new Committee contract address |

### NodeIsInCommittee

Thrown when attempting to modify a node that is in the committee

```solidity
error NodeIsInCommittee(NodeId nodeId)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node in the committee |

### AddressWasAlreadyAssignedToNode

Thrown when an address is already assigned to a node

```solidity
error AddressWasAlreadyAssignedToNode(address nodeAddress)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeAddress | address | The address that is already assigned |

### AddressIsNotAssignedToAnyNode

Thrown when an address is not assigned to any node

```solidity
error AddressIsNotAssignedToAnyNode(address nodeAddress)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeAddress | address | The address that is not assigned |

### PassiveNodeAlreadyExistsForAddress

Thrown when a passive node already exists for an address

```solidity
error PassiveNodeAlreadyExistsForAddress(address nodeAddress, NodeId nodeId)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeAddress | address | The address with an existing passive node |
| nodeId | NodeId | The ID of the existing passive node |

### AddressInUseByPassiveNodes

Thrown when an address is in use by passive nodes

```solidity
error AddressInUseByPassiveNodes(address nodeAddress)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeAddress | address | The address in use |

### InvalidPublicKey

Thrown when an invalid public key is provided

```solidity
error InvalidPublicKey(bytes32[2] publicKey)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| publicKey | bytes32[2] | The invalid public key |

### InvalidPublicKeyForSender

Thrown when the public key doesn't match the sender

```solidity
error InvalidPublicKeyForSender(bytes32[2] publicKey, address expected, address sender)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| publicKey | bytes32[2] | The provided public key |
| expected | address | The expected address derived from the public key |
| sender | address | The actual sender address |

### ActiveNodesCannotChangeOwnership

Thrown when attempting to change ownership of an active node

```solidity
error ActiveNodesCannotChangeOwnership()
```

### InvalidIp

Thrown when an invalid IP address is provided

```solidity
error InvalidIp(bytes ip)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| ip | bytes | The invalid IP address |

### ActiveNodeWasNeverRegistered

Thrown when requesting public key for a node that was never registered as active

```solidity
error ActiveNodeWasNeverRegistered(NodeId nodeId)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node |

### PortShouldNotBeZero

Thrown when port is set to zero

```solidity
error PortShouldNotBeZero()
```

### SenderIsNotNodeOwner

Thrown when sender is not the node owner

```solidity
error SenderIsNotNodeOwner()
```

### SenderIsNotNewNodeOwner

Thrown when sender is not the new node owner in ownership transfer

```solidity
error SenderIsNotNewNodeOwner()
```

### InvalidNodeId

Thrown when an invalid node ID is provided

```solidity
error InvalidNodeId(NodeId nodeId, uint256 nodeIdCounter)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The invalid node ID |
| nodeIdCounter | uint256 | The current node ID counter |

### nodeNotInCurrentOrNextCommittee

```solidity
modifier nodeNotInCurrentOrNextCommittee(NodeId nodeId)
```

**dev:** _Ensures that the node is not in the current or next committee_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The node ID to check |

### nodeExists

```solidity
modifier nodeExists(NodeId nodeId)
```

**dev:** _Ensures that the node exists (either active or passive)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The node ID to check |

### validIp

```solidity
modifier validIp(bytes ip)
```

**dev:** _Checks if a provided IP address is valid IPv4 or IPv6_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| ip | bytes | The IP address to validate |

### validPort

```solidity
modifier validPort(uint16 port)
```

**dev:** _Validates that a port number is not zero_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| port | uint16 | The port to validate |

### validPubKey

```solidity
modifier validPubKey(bytes32[2] publicKey)
```

**dev:** _Validates that the public key is not zero_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| publicKey | bytes32[2] | The public key to validate |

### onlyNodeOwner

```solidity
modifier onlyNodeOwner(NodeId nodeId)
```

**dev:** _Ensures that the caller is the owner of the specified node_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The node ID to check ownership for |

### initialize

Initializes the Nodes contract

```solidity
function initialize(address initialAuthority, struct INodes.Node[] initialNodes, bytes32[2][] nodesPublicKeys) external
```

**dev:** _This function is called only once during contract deployment following the proxy pattern_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| initialAuthority | address | The address of the initial access control authority |
| initialNodes | struct INodes.Node[] | Array of initial nodes to register |
| nodesPublicKeys | bytes32[2][] | Array of public keys corresponding to initial nodes |

### setCommittee

Sets the Committee contract address

```solidity
function setCommittee(contract ICommittee committeeAddress) external
```

**dev:** _Only callable by authorized addresses (restricted)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| committeeAddress | contract ICommittee | The address of the Committee contract |

### registerNode

Registers a new active node

```solidity
function registerNode(bytes ip, bytes32[2] publicKey, uint16 port) external payable
```

**dev:** _Validates IP, port, and public key, then creates the node as disabled (in staking) by default
The sender must match the address derived from the public key
Can include initial stake via msg.value (should be not less than minimum required)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| ip | bytes | The IP address of the node (IPv4 or IPv6) |
| publicKey | bytes32[2] | The node's public key |
| port | uint16 | The port number the node listens on |

### deleteNode

Deletes a node owned by the caller

```solidity
function deleteNode(NodeId nodeId) external
```

**dev:** _Only callable by the node owner
Node must not be in current or next committee_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node to delete |

### deleteNodeByFoundation

Deletes a node — restricted to the foundation

```solidity
function deleteNodeByFoundation(NodeId nodeId) external
```

**dev:** _Node must not be in the current or next committee_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node to delete |

### requestChangeOwner

Requests to change the owner of a passive node

```solidity
function requestChangeOwner(NodeId nodeId, address newOwner) external
```

**dev:** _Only callable by the current node owner
Only works for passive nodes (active nodes cannot change ownership)
New owner must not already own an active node_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node |
| newOwner | address | The address of the new owner |

### confirmOwnerChange

Confirms a pending ownership change for a passive node

```solidity
function confirmOwnerChange(NodeId nodeId) external
```

**dev:** _Only callable by the new owner specified in the ownership change request
Only works for passive nodes_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node |

### registerPassiveNode

Registers a new passive node

```solidity
function registerPassiveNode(bytes ip, uint16 port) external
```

**dev:** _Passive nodes don't participate in consensus
Multiple passive nodes can be registered per address_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| ip | bytes | The IP address of the node (IPv4 or IPv6) |
| port | uint16 | The port number the node listens on |

### setIpAddress

Sets the IP address and port for a node

```solidity
function setIpAddress(NodeId nodeId, bytes ip, uint16 port) external
```

**dev:** _Only callable by the node owner
Node must not be in the current or next committee_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node |
| ip | bytes | The new IP address (IPv4 or IPv6) |
| port | uint16 | The new port number |

### setDomainName

Sets the domain name for a node

```solidity
function setDomainName(NodeId nodeId, string name) external
```

**dev:** _Only callable by the node owner
Node must not be in the current or next committee_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node |
| name | string | The domain name to set |

### getNode

Gets the node information for a specific node ID

```solidity
function getNode(NodeId nodeId) external view returns (struct INodes.Node node)
```

**dev:** _Reverts if the node doesn't exist_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | struct INodes.Node | The node information |

### getNodeId

Gets the node ID for an active node address

```solidity
function getNodeId(address nodeAddress) external view returns (NodeId nodeId)
```

**dev:** _Reverts if the address is not assigned to any active node_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeAddress | address | The address to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The node ID associated with the address |

### getPassiveNodeIdsForAddress

Gets all passive node IDs for a specific address

```solidity
function getPassiveNodeIdsForAddress(address nodeAddress) external view returns (NodeId[] nodeIds)
```

**dev:** _Reverts if the address has no passive nodes_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeAddress | address | The address to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeIds | NodeId[] | Array of passive node IDs associated with the address |

### getPassiveNodeIds

Gets all passive node IDs in the system

```solidity
function getPassiveNodeIds() external view returns (NodeId[] nodeIds)
```

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeIds | NodeId[] | Array of all passive node IDs |

### getPublicKey

Gets the public key for an active node

```solidity
function getPublicKey(NodeId nodeId) external view returns (bytes32[2] publicKey)
```

**dev:** _Reverts if the node was never registered as an active node_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| publicKey | bytes32[2] | The node's public key |

### getActiveNodeIds

Gets all active node IDs in the system

```solidity
function getActiveNodeIds() external view returns (NodeId[] nodeIds)
```

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeIds | NodeId[] | Array of all active node IDs |

### activeNodeExists

Checks if an active node exists

```solidity
function activeNodeExists(NodeId nodeId) external view returns (bool result)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node to check |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | bool | True if the node exists and is active, false otherwise |

### passiveNodeExists

Checks if a passive node exists

```solidity
function passiveNodeExists(NodeId nodeId) external view returns (bool result)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node to check |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | bool | True if the node exists and is passive, false otherwise |

### _createActiveNode

Creates an active node with the specified parameters

```solidity
function _createActiveNode(NodeId nodeId, address nodeAddress, bytes ip, uint16 port, string domainName, bytes32[2] publicKey) internal
```

**dev:** _Internal function called during node registration_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID to assign to the new node |
| nodeAddress | address | The owner address of the node |
| ip | bytes | The IP address of the node |
| port | uint16 | The port number |
| domainName | string | The domain name (can be empty) |
| publicKey | bytes32[2] | The node's public key |


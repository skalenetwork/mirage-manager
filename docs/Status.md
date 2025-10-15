# Solidity API

## Status

Manages node health monitoring and whitelisting in the FAIR network

### heartbeatInterval

```solidity
Duration heartbeatInterval
```

The maximum time interval allowed between heartbeats before a node is considered unhealthy

### lastHeartbeatTimestamp

```solidity
mapping(NodeId => uint256) lastHeartbeatTimestamp
```

Mapping of node IDs to their last heartbeat timestamp

### committee

```solidity
contract ICommittee committee
```

Reference to the Committee contract

### nodes

```solidity
contract INodes nodes
```

Reference to the Nodes contract

### HeartbeatIntervalUpdated

```solidity
event HeartbeatIntervalUpdated(Duration oldInterval, Duration newInterval)
```

Emitted when the heartbeat interval is updated

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| oldInterval | Duration | The previous heartbeat interval |
| newInterval | Duration | The new heartbeat interval |

### NodeWhitelisted

```solidity
event NodeWhitelisted(NodeId nodeId)
```

Emitted when a node is added to the whitelist

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the whitelisted node |

### NodeRemovedFromWhitelist

```solidity
event NodeRemovedFromWhitelist(NodeId nodeId)
```

Emitted when a node is removed from the whitelist

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the removed node |

### NodeDataRemoved

```solidity
event NodeDataRemoved(NodeId nodeId)
```

Emitted when node data is removed from the contract

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node whose data was removed |

### HeartbeatReceived

```solidity
event HeartbeatReceived(NodeId nodeId, uint256 timestamp)
```

Emitted when a heartbeat is received from a node

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node sending the heartbeat |
| timestamp | uint256 | The timestamp when the heartbeat was received |

### NodeAlreadyWhitelisted

```solidity
error NodeAlreadyWhitelisted(NodeId nodeId)
```

Thrown when attempting to whitelist a node that is already whitelisted

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the already whitelisted node |

### NodeNotWhitelisted

```solidity
error NodeNotWhitelisted(NodeId nodeId)
```

Thrown when attempting to remove a node that is not in the whitelist

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node not found in the whitelist |

### initialize

```solidity
function initialize(address initialAuthority, contract INodes nodesAddress, contract ICommittee committeeAddress) external
```

Initializes the Status contract

_This function is called only once during contract deployment following the proxy pattern_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| initialAuthority | address | The address of the initial access control authority |
| nodesAddress | contract INodes | The address of the Nodes contract |
| committeeAddress | contract ICommittee | The address of the Committee contract |

### alive

```solidity
function alive() external
```

Records a heartbeat from a node

_Only callable by addresses associated with active nodes
Updates the node's last heartbeat timestamp and processes the heartbeat if the node is whitelisted_

### setHeartbeatInterval

```solidity
function setHeartbeatInterval(Duration interval) external
```

Sets the heartbeat interval

_Only callable by authorized addresses (restricted)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| interval | Duration | The new heartbeat interval duration |

### whitelistNode

```solidity
function whitelistNode(NodeId nodeId) external
```

Adds a node to the whitelist

_Only callable by authorized addresses (restricted)
The node must exist (either active or passive) to be whitelisted
If the node is active, notifies the committee of the whitelisting_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node to whitelist |

### removeNodeFromWhitelist

```solidity
function removeNodeFromWhitelist(NodeId nodeId) external
```

Removes a node from the whitelist

_Only callable by authorized addresses (restricted)
If the node is active, notifies the committee that the node was removed from the whitelist_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node to remove from the whitelist |

### nodeRemoved

```solidity
function nodeRemoved(NodeId nodeId) external
```

Cleans up data for a removed node

_Only callable by Nodes contract (restricted)
Removes the node from the whitelist if present and deletes its heartbeat timestamp_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node that was removed |

### getWhitelistedNodes

```solidity
function getWhitelistedNodes() external view returns (NodeId[] nodeIds)
```

Returns the list of all whitelisted nodes

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeIds | NodeId[] | Array of whitelisted node IDs |

### isWhitelisted

```solidity
function isWhitelisted(NodeId nodeId) public view returns (bool whitelisted)
```

Checks if a node is whitelisted

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node to check |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| whitelisted | bool | True if the node is whitelisted, false otherwise |

### isHealthy

```solidity
function isHealthy(NodeId nodeId) public view returns (bool healthy)
```

Checks if a node is healthy based on its last heartbeat

_A node is considered healthy if the time since its last heartbeat is less than the heartbeat interval
Fair chain guarantees that block.timestamp are strictly increasing_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node to check |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| healthy | bool | True if the node is healthy, false otherwise |


# Solidity API

## Status

Manages node health monitoring and whitelisting in the FAIR network

### heartbeatInterval

Maximum allowed time between heartbeats before a node is considered unhealthy

```solidity
Duration heartbeatInterval
```

### lastHeartbeatTimestamp

Mapping of node IDs to their last heartbeat timestamp

```solidity
mapping(NodeId => uint256) lastHeartbeatTimestamp
```

### committee

Reference to the Committee contract

```solidity
contract ICommittee committee
```

### nodes

Reference to the Nodes contract

```solidity
contract INodes nodes
```

### HeartbeatIntervalUpdated

Emitted when the heartbeat interval is updated

```solidity
event HeartbeatIntervalUpdated(Duration oldInterval, Duration newInterval)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| oldInterval | Duration | The previous heartbeat interval |
| newInterval | Duration | The new heartbeat interval |

### NodeWhitelisted

Emitted when a node is added to the whitelist

```solidity
event NodeWhitelisted(NodeId nodeId)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the whitelisted node |

### NodeRemovedFromWhitelist

Emitted when a node is removed from the whitelist

```solidity
event NodeRemovedFromWhitelist(NodeId nodeId)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the removed node |

### NodeDataRemoved

Emitted when node data is removed from the contract

```solidity
event NodeDataRemoved(NodeId nodeId)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node whose data was removed |

### HeartbeatReceived

Emitted when a heartbeat is received from a node

```solidity
event HeartbeatReceived(NodeId nodeId, uint256 timestamp)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node sending the heartbeat |
| timestamp | uint256 | The timestamp when the heartbeat was received |

### NodeAlreadyWhitelisted

Thrown when attempting to whitelist a node that is already whitelisted

```solidity
error NodeAlreadyWhitelisted(NodeId nodeId)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the already whitelisted node |

### NodeNotWhitelisted

Thrown when attempting to remove a node that is not in the whitelist

```solidity
error NodeNotWhitelisted(NodeId nodeId)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node not found in the whitelist |

### initialize

Initializes the Status contract

```solidity
function initialize(address initialAuthority, contract INodes nodesAddress, contract ICommittee committeeAddress) external
```

**dev:** _This function is called only once during contract deployment following the proxy pattern_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| initialAuthority | address | The address of the initial access control authority |
| nodesAddress | contract INodes | The address of the Nodes contract |
| committeeAddress | contract ICommittee | The address of the Committee contract |

### alive

Records a heartbeat from a node

```solidity
function alive() external
```

**dev:** _Only callable by addresses associated with active nodes
Updates the node's last heartbeat timestamp and processes the heartbeat if the node is whitelisted_

### setHeartbeatInterval

Sets the heartbeat interval

```solidity
function setHeartbeatInterval(Duration interval) external
```

**dev:** _Only callable by authorized addresses (restricted)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| interval | Duration | The new heartbeat interval duration |

### whitelistNode

Adds a node to the whitelist

```solidity
function whitelistNode(NodeId nodeId) external
```

**dev:** _Only callable by authorized addresses (restricted)
The node must exist (either active or passive) to be whitelisted
If the node is active, notifies the committee of the whitelisting_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node to whitelist |

### removeNodeFromWhitelist

Removes a node from the whitelist

```solidity
function removeNodeFromWhitelist(NodeId nodeId) external
```

**dev:** _Only callable by authorized addresses (restricted)
If the node is active, notifies the committee that the node was removed from the whitelist_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node to remove from the whitelist |

### nodeRemoved

Cleans up data for a removed node

```solidity
function nodeRemoved(NodeId nodeId) external
```

**dev:** _Only callable by Nodes contract (restricted)
Removes the node from the whitelist if present and deletes its heartbeat timestamp_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node that was removed |

### getWhitelistedNodes

Returns the list of all whitelisted nodes

```solidity
function getWhitelistedNodes() external view returns (NodeId[] nodeIds)
```

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeIds | NodeId[] | Array of whitelisted node IDs |

### isWhitelisted

Checks if a node is whitelisted

```solidity
function isWhitelisted(NodeId nodeId) public view returns (bool whitelisted)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node to check |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| whitelisted | bool | True if the node is whitelisted, false otherwise |

### isHealthy

Checks if a node is healthy based on its last heartbeat

```solidity
function isHealthy(NodeId nodeId) public view returns (bool healthy)
```

**dev:** _A node is considered healthy if the time since its last heartbeat is less than the heartbeat interval
Fair chain guarantees that block.timestamp are strictly increasing_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The ID of the node to check |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| healthy | bool | True if the node is healthy, false otherwise |


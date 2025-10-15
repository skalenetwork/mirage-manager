# Solidity API

## Committee

Manages committee selection and rotation for FAIR network

_Orchestrates node eligibility, committee formation, and DKG integration
Maintains updated Node pool for random sampling for committee member selection based on stake_

### CommitteeAuxiliary

_Auxiliary structure to store committee node information
Contains a set of node IDs for efficient membership checks_

```solidity
struct CommitteeAuxiliary {
  struct TypedSet.NodeIdSet nodes;
}
```

### dkg

```solidity
contract IDkg dkg
```

Reference to the DKG contract

### nodes

```solidity
contract INodes nodes
```

Reference to the Nodes contract

### status

```solidity
contract IStatus status
```

Reference to the Status contract

### staking

```solidity
contract IStaking staking
```

Reference to the Staking contract

### skaleRng

```solidity
address skaleRng
```

Address of the SKALE RNG contract for randomness

### committees

```solidity
mapping(CommitteeIndex => struct ICommittee.Committee) committees
```

Mapping from committee index to committee data

### lastCommitteeIndex

```solidity
CommitteeIndex lastCommitteeIndex
```

Index of the last created committee

### committeeSize

```solidity
uint256 committeeSize
```

Number of nodes in a committee

### transitionDelay

```solidity
Duration transitionDelay
```

Delay before a committee becomes active after DKG completion

### minTransitionDelay

```solidity
Duration minTransitionDelay
```

Minimum allowed transition delay

### version

```solidity
string version
```

Version string for the committee contract

### NodeBecomesEligible

```solidity
event NodeBecomesEligible(NodeId node)
```

Emitted when a node becomes eligible for committee selection

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node that became eligible |

### NodeLosesEligibility

```solidity
event NodeLosesEligibility(NodeId node)
```

Emitted when a node loses eligibility for committee selection

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node that lost eligibility |

### SkaleRNGEnabled

```solidity
event SkaleRNGEnabled(address rng)
```

Emitted when SKALE RNG is enabled

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| rng | address | The address of the RNG contract |

### SkaleRNGDisabled

```solidity
event SkaleRNGDisabled()
```

Emitted when SKALE RNG is disabled

### TransitionDelayUpdated

```solidity
event TransitionDelayUpdated(Duration oldDelay, Duration newDelay)
```

Emitted when the transition delay is updated

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| oldDelay | Duration | The previous transition delay |
| newDelay | Duration | The new transition delay |

### MinTransitionDelayUpdated

```solidity
event MinTransitionDelayUpdated(Duration oldDelay, Duration newDelay)
```

Emitted when the minimum transition delay is updated

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| oldDelay | Duration | The previous minimum delay |
| newDelay | Duration | The new minimum delay |

### CommitteeSelected

```solidity
event CommitteeSelected(CommitteeIndex committeeIndex, NodeId[] nodes, DkgId dkgId)
```

Emitted when a new committee is selected

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| committeeIndex | CommitteeIndex | The index of the selected committee |
| nodes | NodeId[] | The array of selected node IDs |
| dkgId | DkgId | The DKG round ID for this committee |

### CommitteeSizeUpdated

```solidity
event CommitteeSizeUpdated(uint256 oldSize, uint256 newSize)
```

Emitted when the committee size is updated

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| oldSize | uint256 | The previous committee size |
| newSize | uint256 | The new committee size |

### DkgUpdated

```solidity
event DkgUpdated(contract IDkg oldDkg, contract IDkg newDkg)
```

Emitted when the DKG contract address is updated

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| oldDkg | contract IDkg | The previous DKG contract address |
| newDkg | contract IDkg | The new DKG contract address |

### NodesUpdated

```solidity
event NodesUpdated(contract INodes oldNodes, contract INodes newNodes)
```

Emitted when the Nodes contract address is updated

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| oldNodes | contract INodes | The previous Nodes contract address |
| newNodes | contract INodes | The new Nodes contract address |

### StatusUpdated

```solidity
event StatusUpdated(contract IStatus oldStatus, contract IStatus newStatus)
```

Emitted when the Status contract address is updated

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| oldStatus | contract IStatus | The previous Status contract address |
| newStatus | contract IStatus | The new Status contract address |

### StakingUpdated

```solidity
event StakingUpdated(contract IStaking oldStaking, contract IStaking newStaking)
```

Emitted when the Staking contract address is updated

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| oldStaking | contract IStaking | The previous Staking contract address |
| newStaking | contract IStaking | The new Staking contract address |

### CommitteeDkgCompleted

```solidity
event CommitteeDkgCompleted(CommitteeIndex committeeIndex, DkgId dkgId, Timestamp startingTimestamp)
```

Emitted when a committee's DKG completes successfully

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| committeeIndex | CommitteeIndex | The index of the committee |
| dkgId | DkgId | The DKG round ID |
| startingTimestamp | Timestamp | The timestamp when the committee becomes active |

### SenderIsNotDkg

```solidity
error SenderIsNotDkg(address sender)
```

Thrown when the sender is not the DKG contract

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| sender | address | The address that attempted the call |

### CommitteeNotFound

```solidity
error CommitteeNotFound(CommitteeIndex index)
```

Thrown when referencing a committee that doesn't exist

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| index | CommitteeIndex | The index of the non-existent committee |

### InvalidSkaleRngContract

```solidity
error InvalidSkaleRngContract(address rng)
```

Thrown when an invalid SKALE RNG contract is provided

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| rng | address | The invalid RNG contract address |

### NodeNotActive

```solidity
error NodeNotActive(NodeId node)
```

Thrown when a node is not active

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The inactive node |

### TransitionDelayTooShort

```solidity
error TransitionDelayTooShort()
```

Thrown when the transition delay is too short

### CommitteeRotationInProgress

```solidity
error CommitteeRotationInProgress()
```

Thrown when attempting to select a new committee while rotation is in progress

### onlyDkg

```solidity
modifier onlyDkg()
```

_Ensures that the caller is the DKG contract_

### onlyNonZeroAddress

```solidity
modifier onlyNonZeroAddress(address addr)
```

### initialize

```solidity
function initialize(address initialAuthority, contract INodes nodesAddress, struct IDkg.G2Point commonPublicKey, NodeId[] nodeIds) external
```

Initializes the Committee contract

_This function is called only once during contract deployment following the proxy pattern_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| initialAuthority | address | The address of the initial access control authority |
| nodesAddress | contract INodes | The address of the Nodes contract |
| commonPublicKey | struct IDkg.G2Point | The common public key for the initial committee |
| nodeIds | NodeId[] | The array of node IDs for the initial committee |

### select

```solidity
function select() external
```

Selects a new committee from eligible nodes

_Only callable by authorized addresses (restricted)
Flushes rewards before selection and initiates DKG for the new committee
Reverts if a committee rotation is already in progress_

### setMinTransitionDelay

```solidity
function setMinTransitionDelay(Duration delay) external
```

Sets the minimum transition delay

_Only callable by authorized addresses (restricted)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| delay | Duration | The new minimum transition delay |

### setRNG

```solidity
function setRNG(address newRNG) external
```

Sets the SKALE RNG contract address

_Only callable by authorized addresses (restricted)
Validates that the RNG contract returns a non-zero random number_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| newRNG | address | The address of the new RNG contract |

### disableRNG

```solidity
function disableRNG() external
```

Disables the SKALE RNG and falls back to block.prevrandao

_Only callable by authorized addresses (restricted)_

### setDkg

```solidity
function setDkg(contract IDkg dkgAddress) external
```

Sets the DKG contract address

_Only callable by authorized addresses (restricted)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| dkgAddress | contract IDkg | The address of the new DKG contract |

### setNodes

```solidity
function setNodes(contract INodes nodesAddress) external
```

Sets the Nodes contract address

_Only callable by authorized addresses (restricted)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodesAddress | contract INodes | The address of the new Nodes contract |

### setStatus

```solidity
function setStatus(contract IStatus statusAddress) external
```

Sets the Status contract address

_Only callable by authorized addresses (restricted)
Also updates the pool's status reference_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| statusAddress | contract IStatus | The address of the new Status contract |

### setStaking

```solidity
function setStaking(contract IStaking stakingAddress) external
```

Sets the Staking contract address

_Only callable by authorized addresses (restricted)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| stakingAddress | contract IStaking | The address of the new Staking contract |

### setVersion

```solidity
function setVersion(string newVersion) external
```

Sets the fair-manager version string

_Only callable by authorized addresses (restricted)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| newVersion | string | The new version string |

### processSuccessfulDkg

```solidity
function processSuccessfulDkg(DkgId round) external
```

Processes a successful DKG completion

_Only callable by the DKG contract
Sets the committee's common public key and activation timestamp_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| round | DkgId | The DKG round ID that completed |

### setCommitteeSize

```solidity
function setCommitteeSize(uint256 size) external
```

Sets the committee size

_Only callable by authorized addresses (restricted)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| size | uint256 | The new committee size |

### setTransitionDelay

```solidity
function setTransitionDelay(Duration delay) external
```

Sets the transition delay

_Only callable by authorized addresses (restricted)
Delay must be greater than minTransitionDelay_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| delay | Duration | The new transition delay |

### nodeRemoved

```solidity
function nodeRemoved(NodeId node) external
```

Called when a node is removed

_Only callable by Nodes contract (restricted)
Removes the node from the eligible pool_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The ID of the removed node |

### nodeWhitelisted

```solidity
function nodeWhitelisted(NodeId node) external
```

Called when a node is whitelisted

_Only callable by Status contract (restricted)
Makes the node eligible if it has stake and is healthy_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The ID of the whitelisted node |

### nodeRemovedFromWhitelist

```solidity
function nodeRemovedFromWhitelist(NodeId node) external
```

Called when a node is blacklisted

_Only callable by Status contract (restricted)
Removes the node from the eligible pool_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The ID of the blacklisted node |

### processHeartbeat

```solidity
function processHeartbeat(NodeId node) external
```

Processes a heartbeat from a node

_Only callable by Status contract (restricted)
Updates node weight in the pool or makes it eligible if conditions are met
Ejects unhealthy nodes after processing_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The ID of the node sending the heartbeat |

### updateWeight

```solidity
function updateWeight(NodeId node, uint256 share) external
```

Updates a node's weight in the eligible pool

_Only callable by Staking contract (restricted)
Adds, updates, or removes the node based on weight and whitelist status_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The ID of the node |
| share | uint256 | The node's share (converted to weight) |

### getCommittee

```solidity
function getCommittee(CommitteeIndex committeeIndex) external view returns (struct ICommittee.Committee committee)
```

Gets the committee information for a specific index

_Reverts if the committee doesn't exist_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| committeeIndex | CommitteeIndex | The index of the committee to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| committee | struct ICommittee.Committee | The committee information |

### isNodeInCurrentOrNextCommittee

```solidity
function isNodeInCurrentOrNextCommittee(NodeId node) external view returns (bool result)
```

Checks if a node is in the current or next committee

_Returns true if the node is found in either the current or next committee_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node ID to check |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | bool | True if the node is in current or next committee, false otherwise |

### ejectUnhealthyNode

```solidity
function ejectUnhealthyNode() public
```

Ejects an unhealthy node from the eligible pool

_Checks the oldest node in the pool and removes it if unhealthy
Returns early if pool is empty. Only affects nodes that are not healthy._

### getActiveCommitteeIndex

```solidity
function getActiveCommitteeIndex() public view returns (CommitteeIndex committeeIndex)
```

Gets the index of the currently active committee

_Iterates backwards from the last committee to find the one that has started_

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| committeeIndex | CommitteeIndex | The index of the active committee |


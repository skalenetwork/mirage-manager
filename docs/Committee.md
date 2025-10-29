# Solidity API

## Committee

Manages committee selection and rotation for the FAIR network

**dev:** _Orchestrates node eligibility, committee formation, and DKG integration
Maintains a weighted pool of eligible nodes for random, stake-weighted sampling_

### CommitteeAuxiliary

**dev:** _Auxiliary structure to store committee node information
Contains a set of node IDs for efficient O(1) membership checks_

```solidity
struct CommitteeAuxiliary {
  struct TypedSet.NodeIdSet nodes;
}
```

### dkg

Reference to the DKG contract

```solidity
contract IDkg dkg
```

### nodes

Reference to the Nodes contract

```solidity
contract INodes nodes
```

### status

Reference to the Status contract

```solidity
contract IStatus status
```

### staking

Reference to the Staking contract

```solidity
contract IStaking staking
```

### skaleRng

Address of the SKALE RNG contract for randomness

```solidity
address skaleRng
```

### committees

Mapping from committee index to committee data

```solidity
mapping(CommitteeIndex => struct ICommittee.Committee) committees
```

### lastCommitteeIndex

Index of the last created committee

```solidity
CommitteeIndex lastCommitteeIndex
```

### committeeSize

Number of nodes in a committee

```solidity
uint256 committeeSize
```

### transitionDelay

Delay before a committee becomes active after DKG completion

```solidity
Duration transitionDelay
```

### minTransitionDelay

Minimum allowed transition delay

```solidity
Duration minTransitionDelay
```

### version

Version string for the committee contract

```solidity
string version
```

### _pool

```solidity
struct PoolLibrary.Pool _pool
```

**dev:** _Pool of nodes for committee selection_

### NodeBecomesEligible

Emitted when a node becomes eligible for committee selection

```solidity
event NodeBecomesEligible(NodeId node)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node that became eligible |

### NodeLosesEligibility

Emitted when a node loses eligibility for committee selection

```solidity
event NodeLosesEligibility(NodeId node)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node that lost eligibility |

### SkaleRNGEnabled

Emitted when SKALE RNG is enabled

```solidity
event SkaleRNGEnabled(address rng)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| rng | address | The address of the RNG contract |

### SkaleRNGDisabled

Emitted when SKALE RNG is disabled

```solidity
event SkaleRNGDisabled()
```

### TransitionDelayUpdated

Emitted when the transition delay is updated

```solidity
event TransitionDelayUpdated(Duration oldDelay, Duration newDelay)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| oldDelay | Duration | The previous transition delay |
| newDelay | Duration | The new transition delay |

### MinTransitionDelayUpdated

Emitted when the minimum transition delay is updated

```solidity
event MinTransitionDelayUpdated(Duration oldDelay, Duration newDelay)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| oldDelay | Duration | The previous minimum delay |
| newDelay | Duration | The new minimum delay |

### CommitteeSelected

Emitted when a new committee is selected

```solidity
event CommitteeSelected(CommitteeIndex committeeIndex, NodeId[] nodes, DkgId dkgId)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| committeeIndex | CommitteeIndex | The index of the selected committee |
| nodes | NodeId[] | The array of selected node IDs |
| dkgId | DkgId | The DKG round ID for this committee |

### CommitteeSizeUpdated

Emitted when the committee size is updated

```solidity
event CommitteeSizeUpdated(uint256 oldSize, uint256 newSize)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| oldSize | uint256 | The previous committee size |
| newSize | uint256 | The new committee size |

### DkgUpdated

Emitted when the DKG contract address is updated

```solidity
event DkgUpdated(contract IDkg oldDkg, contract IDkg newDkg)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| oldDkg | contract IDkg | The previous DKG contract address |
| newDkg | contract IDkg | The new DKG contract address |

### NodesUpdated

Emitted when the Nodes contract address is updated

```solidity
event NodesUpdated(contract INodes oldNodes, contract INodes newNodes)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| oldNodes | contract INodes | The previous Nodes contract address |
| newNodes | contract INodes | The new Nodes contract address |

### StatusUpdated

Emitted when the Status contract address is updated

```solidity
event StatusUpdated(contract IStatus oldStatus, contract IStatus newStatus)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| oldStatus | contract IStatus | The previous Status contract address |
| newStatus | contract IStatus | The new Status contract address |

### StakingUpdated

Emitted when the Staking contract address is updated

```solidity
event StakingUpdated(contract IStaking oldStaking, contract IStaking newStaking)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| oldStaking | contract IStaking | The previous Staking contract address |
| newStaking | contract IStaking | The new Staking contract address |

### CommitteeDkgCompleted

Emitted when a committee's DKG completes successfully

```solidity
event CommitteeDkgCompleted(CommitteeIndex committeeIndex, DkgId dkgId, Timestamp startingTimestamp)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| committeeIndex | CommitteeIndex | The index of the committee |
| dkgId | DkgId | The DKG round ID |
| startingTimestamp | Timestamp | The timestamp when the committee becomes active |

### SenderIsNotDkg

Thrown when the sender is not the DKG contract

```solidity
error SenderIsNotDkg(address sender)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| sender | address | The address that attempted the call |

### CommitteeNotFound

Thrown when referencing a committee that doesn't exist

```solidity
error CommitteeNotFound(CommitteeIndex index)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| index | CommitteeIndex | The index of the non-existent committee |

### InvalidSkaleRngContract

Thrown when an invalid SKALE RNG contract is provided

```solidity
error InvalidSkaleRngContract(address rng)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| rng | address | The invalid RNG contract address |

### NodeNotActive

Thrown when a node is not active

```solidity
error NodeNotActive(NodeId node)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The inactive node |

### TransitionDelayTooShort

Thrown when the transition delay is too short

```solidity
error TransitionDelayTooShort()
```

### CommitteeRotationInProgress

Thrown when attempting to select a new committee while rotation is in progress

```solidity
error CommitteeRotationInProgress()
```

### onlyDkg

```solidity
modifier onlyDkg()
```

**dev:** _Ensures that the caller is the DKG contract_

### onlyNonZeroAddress

```solidity
modifier onlyNonZeroAddress(address addr)
```

### initialize

Initializes the Committee contract

```solidity
function initialize(address initialAuthority, contract INodes nodesAddress, struct IDkg.G2Point commonPublicKey, NodeId[] nodeIds) external
```

**dev:** _This function is called only once during contract deployment following the proxy pattern_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| initialAuthority | address | The address of the initial access control authority |
| nodesAddress | contract INodes | The address of the Nodes contract |
| commonPublicKey | struct IDkg.G2Point | The common public key for the initial committee |
| nodeIds | NodeId[] | The array of node IDs for the initial committee |

### select

Selects a new committee from eligible nodes

```solidity
function select() external
```

**dev:** _Only callable by authorized addresses (restricted)
Flushes rewards before selection and initiates DKG for the new committee
Reverts if a committee rotation is already in progress_

### setMinTransitionDelay

Sets the minimum transition delay

```solidity
function setMinTransitionDelay(Duration delay) external
```

**dev:** _Only callable by authorized addresses (restricted)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| delay | Duration | The new minimum transition delay |

### setRNG

Sets the SKALE RNG contract address

```solidity
function setRNG(address newRNG) external
```

**dev:** _Only callable by authorized addresses (restricted)
Validates that the RNG contract returns a non-zero random number_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| newRNG | address | The address of the new RNG contract |

### disableRNG

Disables the SKALE RNG and falls back to block.prevrandao

```solidity
function disableRNG() external
```

**dev:** _Only callable by authorized addresses (restricted)_

### setDkg

Sets the DKG contract address

```solidity
function setDkg(contract IDkg dkgAddress) external
```

**dev:** _Only callable by authorized addresses (restricted)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| dkgAddress | contract IDkg | The address of the new DKG contract |

### setNodes

Sets the Nodes contract address

```solidity
function setNodes(contract INodes nodesAddress) external
```

**dev:** _Only callable by authorized addresses (restricted)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodesAddress | contract INodes | The address of the new Nodes contract |

### setStatus

Sets the Status contract address

```solidity
function setStatus(contract IStatus statusAddress) external
```

**dev:** _Only callable by authorized addresses (restricted)
Also updates the pool's Status reference_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| statusAddress | contract IStatus | The address of the new Status contract |

### setStaking

Sets the Staking contract address

```solidity
function setStaking(contract IStaking stakingAddress) external
```

**dev:** _Only callable by authorized addresses (restricted)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| stakingAddress | contract IStaking | The address of the new Staking contract |

### setVersion

Sets the fair-manager version string

```solidity
function setVersion(string newVersion) external
```

**dev:** _Only callable by authorized addresses (restricted)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| newVersion | string | The new version string |

### processSuccessfulDkg

Processes a successful DKG completion

```solidity
function processSuccessfulDkg(DkgId round) external
```

**dev:** _Only callable by the DKG contract
Sets the committee's common public key and activation timestamp_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| round | DkgId | The DKG round ID that completed |

### setCommitteeSize

Sets the committee size

```solidity
function setCommitteeSize(uint256 size) external
```

**dev:** _Only callable by authorized addresses (restricted)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| size | uint256 | The new committee size |

### setTransitionDelay

Sets the transition delay

```solidity
function setTransitionDelay(Duration delay) external
```

**dev:** _Only callable by authorized addresses (restricted)
Delay must be greater than minTransitionDelay_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| delay | Duration | The new transition delay |

### nodeRemoved

Called when a node is removed

```solidity
function nodeRemoved(NodeId node) external
```

**dev:** _Only callable by Nodes contract (restricted)
Removes the node from the eligible pool_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The ID of the removed node |

### nodeWhitelisted

Called when a node is whitelisted

```solidity
function nodeWhitelisted(NodeId node) external
```

**dev:** _Only callable by Status contract (restricted)
Makes the node eligible if it has stake and is healthy_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The ID of the whitelisted node |

### nodeRemovedFromWhitelist

Called when a node is blacklisted

```solidity
function nodeRemovedFromWhitelist(NodeId node) external
```

**dev:** _Only callable by Status contract (restricted)
Removes the node from the eligible pool_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The ID of the blacklisted node |

### processHeartbeat

Processes a heartbeat from a node

```solidity
function processHeartbeat(NodeId node) external
```

**dev:** _Only callable by Status contract (restricted)
Updates node weight in the pool or makes it eligible if conditions are met
Ejects unhealthy nodes after processing_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The ID of the node sending the heartbeat |

### updateWeight

Updates a node's weight in the eligible pool

```solidity
function updateWeight(NodeId node, uint256 share) external
```

**dev:** _Only callable by Staking contract (restricted)
Adds, updates, or removes the node based on weight and whitelist status_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The ID of the node |
| share | uint256 | The node's share (converted to weight) |

### getCommittee

Gets the committee information for a specific index

```solidity
function getCommittee(CommitteeIndex committeeIndex) external view returns (struct ICommittee.Committee committee)
```

**dev:** _Reverts if the committee doesn't exist_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| committeeIndex | CommitteeIndex | The index of the committee to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| committee | struct ICommittee.Committee | The committee information |

### isNodeInCurrentOrNextCommittee

Checks if a node is in the current or next committee

```solidity
function isNodeInCurrentOrNextCommittee(NodeId node) external view returns (bool result)
```

**dev:** _Returns true if the node is found in either the current or next committee_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node ID to check |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | bool | True if the node is in current or next committee, false otherwise |

### ejectUnhealthyNode

Ejects an unhealthy node from the eligible pool

```solidity
function ejectUnhealthyNode() public
```

**dev:** _Checks the oldest node in the pool and removes it if unhealthy
Returns early if the pool is empty. Only affects nodes that are not healthy._

### getActiveCommitteeIndex

Gets the index of the currently active committee

```solidity
function getActiveCommitteeIndex() public view returns (CommitteeIndex committeeIndex)
```

**dev:** _Iterates backwards from the last committee to find the one that has started_

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| committeeIndex | CommitteeIndex | The index of the active committee |


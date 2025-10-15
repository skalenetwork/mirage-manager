# Solidity API

## DKG

Manages Distributed Key Generation (DKG) rounds for committee formation

_Implements the DKG protocol with BROADCAST and ALRIGHT stages to generate
shared public keys. Participants broadcast verification vectors and secret key
contributions, then confirm receipt of all required data before the DKG is marked successful._

### RoundData

_Internal data structure for tracking DKG round state_

```solidity
struct RoundData {
  DkgId id;
  enum IDkg.Status status;
  struct TypedSet.NodeIdSet nodes;
  struct IDkg.G2Point publicKey;
  uint256 startingBlockNumber;
  struct TypedMap.NodeIdToBytes32Map hashedData;
  struct TypedSet.NodeIdSet completed;
}
```

### nodes

```solidity
contract INodes nodes
```

Reference to the Nodes contract

### committee

```solidity
contract ICommittee committee
```

Reference to the Committee contract

### lastDkgId

```solidity
DkgId lastDkgId
```

The ID of the most recently created DKG round

### BroadcastAndKeyShare

```solidity
event BroadcastAndKeyShare(DkgId dkg, NodeId node, struct IDkg.G2Point[] verificationVector, struct IDkg.KeyShare[] secretKeyContribution)
```

Emitted when a node broadcasts its verification vector and key shares

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| dkg | DkgId | The DKG round ID |
| node | NodeId | The node that broadcast the data |
| verificationVector | struct IDkg.G2Point[] | The verification vector |
| secretKeyContribution | struct IDkg.KeyShare[] | The encrypted secret key shares for other nodes |

### AllDataReceived

```solidity
event AllDataReceived(DkgId dkg, NodeId node)
```

Emitted when a node confirms receipt of all required DKG data

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| dkg | DkgId | The DKG round ID |
| node | NodeId | The node that confirmed all data received |

### SuccessfulDkg

```solidity
event SuccessfulDkg(DkgId dkg)
```

Emitted when a DKG round completes successfully

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| dkg | DkgId | The DKG round ID that succeeded |

### DkgRoundCreated

```solidity
event DkgRoundCreated(DkgId dkgId, NodeId[] participants, uint256 startingBlockNumber)
```

Emitted when a new DKG round is created

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| dkgId | DkgId | The new DKG round ID |
| participants | NodeId[] | The array of nodes participating in this round |
| startingBlockNumber | uint256 | The block number when the round started |

### DkgIsNotSuccessful

```solidity
error DkgIsNotSuccessful(DkgId id)
```

DKG round did not complete successfully

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| id | DkgId | The DKG round ID that failed |

### DkgIsNotInBroadcastStage

```solidity
error DkgIsNotInBroadcastStage(DkgId id)
```

Operation requires DKG to be in BROADCAST stage

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| id | DkgId | The DKG round ID |

### DkgIsNotInAlrightStage

```solidity
error DkgIsNotInAlrightStage(DkgId id)
```

Operation requires DKG to be in ALRIGHT stage

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| id | DkgId | The DKG round ID |

### IncorrectVerificationsVectorQuantity

```solidity
error IncorrectVerificationsVectorQuantity(uint256 actual, uint256 expected)
```

Incorrect number of verification vector elements

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| actual | uint256 | The actual number of elements provided |
| expected | uint256 | The expected number of elements (threshold t) |

### IncorrectSecretKeyContributionQuantity

```solidity
error IncorrectSecretKeyContributionQuantity(uint256 actual, uint256 expected)
```

Incorrect number of secret key contribution shares

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| actual | uint256 | The actual number of shares provided |
| expected | uint256 | The expected number of shares (n participants) |

### DuplicatedNodeId

```solidity
error DuplicatedNodeId(NodeId node)
```

A node ID appears more than once in the participant list

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The duplicated node ID |

### NodeDoesNotParticipateInDkg

```solidity
error NodeDoesNotParticipateInDkg(NodeId node)
```

Node is not a participant in this DKG round

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node ID that is not participating |

### NodeAlreadyBroadcasted

```solidity
error NodeAlreadyBroadcasted(NodeId node)
```

Node has already broadcast its data for this round

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node ID that already broadcast |

### IncorrectG2Point

```solidity
error IncorrectG2Point(struct IDkg.G2Point value)
```

The provided G2 point is not valid

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| value | struct IDkg.G2Point | The invalid G2 point |

### NodeIsAlreadyAlright

```solidity
error NodeIsAlreadyAlright(NodeId node)
```

Node has already confirmed all data received

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node ID that already confirmed |

### RoundDoesNotExist

```solidity
error RoundDoesNotExist(DkgId dkg)
```

The specified DKG round does not exist

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| dkg | DkgId | The non-existent DKG round ID |

### onlyBroadcastingDkg

```solidity
modifier onlyBroadcastingDkg(DkgId dkg)
```

_Ensures DKG is in the BROADCAST stage_

### onlyAlrightDkg

```solidity
modifier onlyAlrightDkg(DkgId dkg)
```

_Ensures DKG is in the ALRIGHT stage_

### initialize

```solidity
function initialize(address initialAuthority, contract ICommittee committeeAddress, contract INodes nodesAddress) external
```

Initializes the DKG contract

_Sets up access control and references to Committee and Nodes contracts_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| initialAuthority | address | The address of the access manager |
| committeeAddress | contract ICommittee | The address of the Committee contract |
| nodesAddress | contract INodes | The address of the Nodes contract |

### alright

```solidity
function alright(DkgId dkg) external
```

Confirms that a node has received all DKG data

_Only callable during ALRIGHT stage. When threshold is reached, DKG succeeds._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| dkg | DkgId | The DKG round ID |

### broadcast

```solidity
function broadcast(DkgId dkg, struct IDkg.G2Point[] verificationVector, struct IDkg.KeyShare[] secretKeyContribution) external
```

Broadcasts verification vector and secret key contributions for DKG

_Only callable during BROADCAST stage. Validates vector and contribution sizes.
When all nodes broadcast, advances to ALRIGHT stage._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| dkg | DkgId | The DKG round ID |
| verificationVector | struct IDkg.G2Point[] | The verification vector (length t) for the secret polynomial |
| secretKeyContribution | struct IDkg.KeyShare[] | The encrypted secret key shares (length n) for other nodes |

### generate

```solidity
function generate(NodeId[] participants) external returns (DkgId dkg)
```

Generates a new DKG round with the specified participants

_Only callable by Committee contract (restricted). Creates a new round in BROADCAST stage._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| participants | NodeId[] | The array of node IDs that will participate in this DKG round |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| dkg | DkgId | The ID of the newly created DKG round |

### isNodeBroadcasted

```solidity
function isNodeBroadcasted(DkgId dkg, NodeId node) external view returns (bool broadcasted)
```

Checks if a node has broadcast its data for a DKG round

_Returns true if the node's hashed data is stored in the round_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| dkg | DkgId | The DKG round ID |
| node | NodeId | The node ID to check |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| broadcasted | bool | True if the node has broadcast, false otherwise |

### getParticipants

```solidity
function getParticipants(DkgId dkg) external view returns (NodeId[] participants)
```

Gets the list of participants in a DKG round

_Returns all node IDs that were registered for this DKG round_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| dkg | DkgId | The DKG round ID |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| participants | NodeId[] | The array of participating node IDs |

### getPublicKey

```solidity
function getPublicKey(DkgId dkg) external view returns (struct IDkg.G2Point publicKey)
```

Gets the common public key generated by a successful DKG round

_Only returns the key if the DKG round completed successfully_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| dkg | DkgId | The DKG round ID |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| publicKey | struct IDkg.G2Point | The common public key generated by the DKG |

### getRound

```solidity
function getRound(DkgId dkg) external view returns (struct IDkg.Round round)
```

Gets comprehensive information about a DKG round

_Returns all round data including participant status and hashed broadcast data_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| dkg | DkgId | The DKG round ID |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| round | struct IDkg.Round | The complete round information structure |


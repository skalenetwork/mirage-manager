# Solidity API

## Staking

Manages staking operations for FAIR network nodes

**dev:** _Implements a two-level fund structure with reward distribution, fee collection, and exit-queue management_

### DEFAULT_FEE_RATE

Default fee rate starting value (100% of precision; maximum possible fee rate)

```solidity
uint16 DEFAULT_FEE_RATE
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

### rewardWalletBeacon

Reference to the reward wallet beacon contract

```solidity
contract IBeacon rewardWalletBeacon
```

### totalDisabled

Total amount of funds in disabled nodes

```solidity
Fair totalDisabled
```

### stakeLimit

Maximum stake allowed per node

```solidity
Fair stakeLimit
```

### selfStakeRequirement

Minimum self-stake required from node owners

```solidity
Fair selfStakeRequirement
```

### AllowedReceiverAdded

Emitted when an address is added to a node's allowed fee receivers list

```solidity
event AllowedReceiverAdded(NodeId node, address receiver)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node ID |
| receiver | address | The address added to the allowed receivers list |

### AllowedReceiverRemoved

Emitted when an address is removed from a node's allowed receivers list

```solidity
event AllowedReceiverRemoved(NodeId node, address receiver)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node ID |
| receiver | address | The address removed from the allowed receivers list |

### FeeClaimRequested

Emitted when a fee claim is requested

```solidity
event FeeClaimRequested(NodeId node, address from, address to, Fair amount)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node from which fees are claimed |
| from | address | The address requesting the claim |
| to | address | The address to receive the fees |
| amount | Fair | The amount of fees claimed |

### NodeRewardReceived

Emitted when a node receives a reward

```solidity
event NodeRewardReceived(NodeId node, Fair amount)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node receiving the reward |
| amount | Fair | The amount of the reward |

### RetrieveRequested

Emitted when a stake retrieval is requested

```solidity
event RetrieveRequested(address sender, NodeId node, Fair amount)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| sender | address | The address requesting the retrieval |
| node | NodeId | The node from which stake is being retrieved |
| amount | Fair | The amount being retrieved |

### RewardReceived

Emitted when the contract receives a reward payment

```solidity
event RewardReceived(address sender, uint256 amount)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| sender | address | The address sending the reward |
| amount | uint256 | The amount of the reward |

### RewardWalletCreated

Emitted when a reward wallet is created for a node

```solidity
event RewardWalletCreated(NodeId node)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node for which the reward wallet was created |

### Staked

Emitted when stake is added to a node

```solidity
event Staked(address sender, NodeId node, Fair amount)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| sender | address | The address staking |
| node | NodeId | The node receiving the stake |
| amount | Fair | The amount staked |

### StakedToNewNode

Emitted when a user stakes to a new node for the first time

```solidity
event StakedToNewNode(address sender, NodeId node)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| sender | address | The address staking |
| node | NodeId | The new node receiving stake |

### StoppedStaking

Emitted when a user completely withdraws from a node

```solidity
event StoppedStaking(address sender, NodeId node)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| sender | address | The address that stopped staking |
| node | NodeId | The node from which staking stopped |

### NodeDataRemoved

Emitted when node data is removed from the contract

```solidity
event NodeDataRemoved(NodeId node)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node whose data was removed |

### NodeDisabled

Emitted when a node is disabled

```solidity
event NodeDisabled(NodeId node)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node that was disabled |

### NodeEnabled

Emitted when a node is enabled

```solidity
event NodeEnabled(NodeId node)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node that was enabled |

### RetrievingDelayUpdated

Emitted when the retrieving delay is updated

```solidity
event RetrievingDelayUpdated(Timestamp retrievingDelay)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| retrievingDelay | Timestamp | The new retrieving delay |

### StakeLimitUpdated

Emitted when the stake limit is updated

```solidity
event StakeLimitUpdated(Fair newLimit)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| newLimit | Fair | The new stake limit per node |

### NodeFeeRateUpdated

Emitted when a node's fee rate is updated

```solidity
event NodeFeeRateUpdated(NodeId node, uint16 oldFeeRate, uint16 newFeeRate)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node whose fee rate was updated |
| oldFeeRate | uint16 | The previous fee rate |
| newFeeRate | uint16 | The new fee rate |

### RewardWalletBeaconUpdated

Emitted when the reward wallet beacon address is updated

```solidity
event RewardWalletBeaconUpdated(contract IBeacon oldBeacon, contract IBeacon newBeacon)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| oldBeacon | contract IBeacon | The previous beacon address |
| newBeacon | contract IBeacon | The new beacon address |

### SelfStakeRequirementUpdated

Emitted when the self-stake requirement is updated

```solidity
event SelfStakeRequirementUpdated(Fair amount)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | Fair | The new self-stake requirement |

### SelfStakeProvided

Emitted when a node owner provides self-stake

```solidity
event SelfStakeProvided(NodeId nodeId, Fair amount)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The node receiving self-stake |
| amount | Fair | The amount of self-stake provided |

### FeeRateIsIncorrect

Thrown when the provided fee rate exceeds the maximum allowed

```solidity
error FeeRateIsIncorrect(uint16 feeRate)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| feeRate | uint16 | The invalid fee rate that was provided |

### OnlyFeeReductionIsAllowed

Thrown when attempting to increase the fee rate of nodes with stake (only reductions are allowed)

```solidity
error OnlyFeeReductionIsAllowed(uint16 currentRate, uint16 newRate)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| currentRate | uint16 | The current fee rate |
| newRate | uint16 | The attempted new fee rate |

### ZeroAmount

Thrown when an operation requires a non-zero amount but zero was provided

```solidity
error ZeroAmount()
```

### ZeroStakeToNode

Thrown when attempting to retrieve from a node where sender has zero stake

```solidity
error ZeroStakeToNode(NodeId node)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node attempted to retrieve from |

### NodeIsAlreadyDisabled

Thrown when attempting to disable an already disabled node

```solidity
error NodeIsAlreadyDisabled(NodeId node)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node that is already disabled |

### NodeIsNotDisabled

Thrown when attempting an operation that requires an enabled node

```solidity
error NodeIsNotDisabled(NodeId node)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node that is not disabled |

### NotAllowedToClaimRewards

Thrown when an unauthorized address attempts to claim rewards

```solidity
error NotAllowedToClaimRewards(address sender)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| sender | address | The unauthorized address |

### StakeLimitExceeded

Thrown when staking/payRewards would exceed the per-node stake limit

```solidity
error StakeLimitExceeded(Fair currentStake, Fair attemptedStake, Fair limit)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| currentStake | Fair | The current stake on the node |
| attemptedStake | Fair | The amount attempting to be staked |
| limit | Fair | The configured stake limit |

### ReceiverIsAlreadyAllowed

Thrown when attempting to add an already allowed receiver

```solidity
error ReceiverIsAlreadyAllowed(address receiver)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| receiver | address | The receiver that is already allowed |

### ReceiverWasNotAllowed

Thrown when attempting to remove a receiver that was not in the list of allowed receivers

```solidity
error ReceiverWasNotAllowed(address receiver)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| receiver | address | The receiver that was not in the allowed list |

### RewardWalletDoesNotExist

Thrown when a Node does not have an associated reward wallet

```solidity
error RewardWalletDoesNotExist(NodeId node)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node whose reward wallet doesn't exist |

### NodeOwnerCannotRetrieveWhileNodeExists

Thrown when a node owner attempts to retrieve stake while their node exists

```solidity
error NodeOwnerCannotRetrieveWhileNodeExists(address nodeOwner, NodeId node)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeOwner | address | The address of the node owner |
| node | NodeId | The existing node |

### InsufficientSelfStake

Thrown when the provided self-stake is less than the required amount

```solidity
error InsufficientSelfStake(Fair provided, Fair required)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| provided | Fair | The amount of self-stake provided |
| required | Fair | The required amount of self-stake |

### InvalidRewardWalletAddress

```solidity
error InvalidRewardWalletAddress()
```

### onlyExistingActiveNode

```solidity
modifier onlyExistingActiveNode(NodeId node)
```

**dev:** _Ensures that the specified node exists and is active_

### receive

Fallback function to receive rewards

```solidity
receive() external payable
```

**dev:** _Emits RewardReceived when funds are sent to the contract
Received funds are automatically shared among all enabled nodes proportionally to stake_

### initialize

Initializes the Staking contract

```solidity
function initialize(address initialAuthority, contract ICommittee committee_, contract INodes nodes_, contract IBeacon rewardWalletBeacon_) external
```

**dev:** _This function is called only once during contract deployment following the proxy pattern_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| initialAuthority | address | The address of the initial access control authority |
| committee_ | contract ICommittee | The address of the Committee contract |
| nodes_ | contract INodes | The address of the Nodes contract |
| rewardWalletBeacon_ | contract IBeacon | The address of the reward wallet beacon contract |

### updateRewardWalletBeacon

Updates the reward wallet beacon address

```solidity
function updateRewardWalletBeacon(contract IBeacon rewardWalletBeacon_) external
```

**dev:** _It's a reinitializer - used once only during contract deployment or upgrade from old version_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| rewardWalletBeacon_ | contract IBeacon | The address of the reward wallet beacon contract |

### addAllowedReceiver

Adds an address to the list of allowed fee receivers for the caller's node

```solidity
function addAllowedReceiver(address receiver) external
```

**dev:** _Only callable by node owners_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| receiver | address | The address to add to the allowed receivers list |

### removeAllowedReceiver

Removes an address from the list of allowed fee receivers for the caller's node

```solidity
function removeAllowedReceiver(address receiver) external
```

**dev:** _Only callable by node owners_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| receiver | address | The address to remove from the allowed receivers list |

### requestAllFees

Requests all earned fees for a specific node

```solidity
function requestAllFees(NodeId node) external
```

**dev:** _Only callable by node owners and allowed receivers_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node whose fees to request |

### requestSendAllFees

Requests to send all earned fees to a specified address

```solidity
function requestSendAllFees(address payable to) external
```

**dev:** _Only callable by node owners
to address must be an allowed receiver if the list is not empty_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| to | address payable | The address to receive the fees |

### setSelfStakeRequirement

Sets the minimum self-stake requirement for nodes

```solidity
function setSelfStakeRequirement(Fair amount) external
```

**dev:** _Only callable by authorized addresses (restricted)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | Fair | The new self-stake requirement |

### disable

Disables a node from receiving network stability rewards

```solidity
function disable(NodeId node) external
```

**dev:** _While disabled, nodes are not eligible for committee selection (removed from root fund)
Disabled nodes can still earn block-rewards if they are part of the current committee
Only callable by the Committee contract (restricted)
Ensures it's weight in committee is set to 0_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node to disable |

### enable

Enables a node to receive network stability rewards

```solidity
function enable(NodeId node) external
```

**dev:** _Only callable by Committee contract (restricted)
Only works on existing (not deleted) active nodes
Updates node's weight in Committee contract after enabling_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node to enable |

### nodeCreated

Called when a new node is created

```solidity
function nodeCreated(NodeId node, address nodeAddress) external payable
```

**dev:** _Only callable by Nodes contract (restricted)
Deploys a reward wallet for the new node and sets node as disabled initially
Validates self-stake requirement and stakes all provided initial stake_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The ID of the newly created node |
| nodeAddress | address | The address of the node owner |

### nodeRemoved

Called when a node is removed

```solidity
function nodeRemoved(NodeId node) external
```

**dev:** _Only callable by Nodes contract (restricted)
Cleans up node data and creates exit requests for node owner's stake and fees
Node must be disabled before removal_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The ID of the node being removed |

### payReward

Pays a reward to a node

```solidity
function payReward(NodeId node) external payable
```

**dev:** _Only works on existing active nodes
Enforces stake limit unless called from the node's reward wallet
Updates committee weight if node is enabled_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node receiving the reward |

### claimRequest

Claims an exit request and transfers funds to the caller

```solidity
function claimRequest(uint256 requestId) external
```

**dev:** _Reverts if the request is still locked or doesn't belong to the caller_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| requestId | uint256 | The ID of the exit request to claim |

### setStakeLimit

Sets the maximum stake allowed per node

```solidity
function setStakeLimit(Fair limit) external
```

**dev:** _Only callable by authorized addresses (restricted)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| limit | Fair | The new stake limit |

### setRetrievingDelay

Sets the delay period for exit requests

```solidity
function setRetrievingDelay(Timestamp delay) external
```

**dev:** _Only callable by authorized addresses (restricted)
Even if delay is 0, the request cannot be created and claimed in the same block_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| delay | Timestamp | The new retrieving delay |

### setFeeRate

Sets the fee rate for the caller's node

```solidity
function setFeeRate(uint16 feeRate) external
```

**dev:** _Only callable by node owners
Fee rate can only be reduced, not increased (except if there are no stakers to the node)
Pulls any pending rewards before updating the rate_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| feeRate | uint16 | The new fee rate (must be <= FEE_RATE_PRECISION) |

### requestRetrieveAll

Requests to retrieve all stake from a specific node

```solidity
function requestRetrieveAll(NodeId node) external
```

**dev:** _Creates an exit request for the caller's entire stake in the node_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node from which to retrieve all stake |

### stake

Stakes to a specific node

```solidity
function stake(NodeId node) external payable
```

**dev:** _Only works on existing active nodes
msg.value must be greater than 0_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node to stake to |

### getNodeShare

Gets the node's share of the total credits

```solidity
function getNodeShare(NodeId node) external view returns (uint256 share)
```

**dev:** _Returns 0 if node is disabled
Accounts for un-pulled rewards from the node's reward wallet_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| share | uint256 | The node's share in credits |

### getRewardWallet

Gets the reward wallet contract for a specific node

```solidity
function getRewardWallet(NodeId node) external view returns (contract IRewardWallet rewardWallet)
```

**dev:** _Reverts if reward wallet doesn't exist_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| rewardWallet | contract IRewardWallet | The reward wallet contract |

### getStakedAmount

Gets the total amount staked by the caller

```solidity
function getStakedAmount() external view returns (Fair amount)
```

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | Fair | The total staked amount |

### getStakedToNodeAmount

Gets the amount the caller has staked to a specific node

```solidity
function getStakedToNodeAmount(NodeId node) external view returns (Fair amount)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | Fair | The staked amount |

### getStakedNodes

Gets the list of nodes the caller has stake in

```solidity
function getStakedNodes() external view returns (NodeId[] stakedNodes)
```

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| stakedNodes | NodeId[] | Array of node IDs |

### getNodeTotalStake

Gets the total stake for a specific node

```solidity
function getNodeTotalStake(NodeId node) external view returns (Fair amount)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | Fair | The total stake on the node |

### getNodeFeeRate

Gets the current fee rate for a specific node

```solidity
function getNodeFeeRate(NodeId node) external view returns (uint16 feeRate)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| feeRate | uint16 | The node's current fee rate |

### getDelegatorsToNode

Gets the list of all delegators (stakers) to a specific node

```solidity
function getDelegatorsToNode(NodeId node) external view returns (address[] delegators)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| delegators | address[] | Array of delegator addresses |

### getDelegatorsToNodeCount

Gets the number of delegators to a specific node

```solidity
function getDelegatorsToNodeCount(NodeId node) external view returns (uint256 count)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| count | uint256 | The number of delegators |

### getExitRequestsCountFor

Gets the number of exit requests for a specific user

```solidity
function getExitRequestsCountFor(address user) external view returns (uint256 count)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| user | address | The user to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| count | uint256 | The number of exit requests |

### getMyTotalInExitQueue

Gets the caller's total amount in the exit queue

```solidity
function getMyTotalInExitQueue() external view returns (Fair amount)
```

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | Fair | The total amount waiting in exit queue |

### getMyExitRequestsCount

Gets the number of exit requests for the caller

```solidity
function getMyExitRequestsCount() external view returns (uint256 count)
```

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| count | uint256 | The number of exit requests |

### isWithinStakeLimit

Checks if a node's current stake is within the configured stake limit

```solidity
function isWithinStakeLimit(NodeId node) external view returns (bool result)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node to check |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | bool | True if within stake limit, false otherwise |

### getExitRequest

Gets information about a specific exit request

```solidity
function getExitRequest(uint256 requestId) external view returns (struct IStaking.ExitRequest request)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| requestId | uint256 | The ID of the exit request |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| request | struct IStaking.ExitRequest | The exit request details |

### getUnlockedExitRequestFor

Gets the first unlocked exit request found for a user starting from a specific index

```solidity
function getUnlockedExitRequestFor(address user, uint256 fromIndex) external view returns (struct IStaking.ExitRequest request)
```

**dev:** _Does limited iterations to avoid DoS and gas limit issues_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| user | address | The user to query |
| fromIndex | uint256 | The index to start searching from |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| request | struct IStaking.ExitRequest | The unlocked exit request |

### getExitRequestAt

Gets an exit request at a specific index for a user

```solidity
function getExitRequestAt(address user, uint256 index) external view returns (struct IStaking.ExitRequest request)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| user | address | The user to query |
| index | uint256 | The index of the exit request |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| request | struct IStaking.ExitRequest | The exit request at the specified index |

### isRequestUnlocked

Checks if an exit request is unlocked and can be claimed

```solidity
function isRequestUnlocked(uint256 requestId) external view returns (bool unlocked)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| requestId | uint256 | The ID of the exit request |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| unlocked | bool | True if the request is unlocked, false otherwise |

### getRetrievingDelay

Gets the current retrieving delay

```solidity
function getRetrievingDelay() external view returns (Timestamp delay)
```

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| delay | Timestamp | The time delay before exit requests can be claimed |

### getTotalInExitQueueFor

Gets the total amount in the exit queue for a specific user

```solidity
function getTotalInExitQueueFor(address user) external view returns (Fair amount)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| user | address | The user to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | Fair | The total amount in exit queue |

### requestRetrieve

Requests to retrieve a specific amount of stake from a node

```solidity
function requestRetrieve(NodeId node, Fair value) public
```

**dev:** _Creates an exit request and updates committee weight if the node is enabled
value must be greater than 0 and less than or equal to the caller's stake in the node_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node from which to retrieve stake |
| value | Fair | The amount to retrieve |

### requestFees

Requests a specific amount of fees for a node

```solidity
function requestFees(NodeId node, Fair amount) public
```

**dev:** _Only callable by allowed receivers or node owner
Creates an exit request for the sender_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node from which to request fees |
| amount | Fair | The amount of fees to request |

### requestSendFees

Requests to send fees to a specific address

```solidity
function requestSendFees(address payable to, Fair amount) public
```

**dev:** _Only callable by node owners
If allowed receivers are configured, destination must be in the list or be the owner_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| to | address payable | The address to receive the fees |
| amount | Fair | The amount of fees to send |

### isNodeEnabled

Checks if a node is currently enabled

```solidity
function isNodeEnabled(NodeId node) public view returns (bool enabled)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node to check |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| enabled | bool | True if the node is enabled, false otherwise |

### getEarnedFeeAmount

Gets the amount of fees earned by a node

```solidity
function getEarnedFeeAmount(NodeId node) public view returns (Fair amount)
```

**dev:** _Includes non-pulled rewards from the reward wallet_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | Fair | The earned fee amount |

### getStakedAmountFor

Gets the total amount staked by a specific holder across all nodes

```solidity
function getStakedAmountFor(address holder) public view returns (Fair amount)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| holder | address | The address to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | Fair | The total staked amount |

### getStakedNodesFor

Gets the list of nodes a specific holder has staked to

```solidity
function getStakedNodesFor(address holder) public view returns (NodeId[] stakedNodes)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| holder | address | The address to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| stakedNodes | NodeId[] | Array of node IDs |

### getStakedToNodeAmountFor

Gets the amount a specific holder has staked to a specific node

```solidity
function getStakedToNodeAmountFor(NodeId node, address holder) public view returns (Fair amount)
```

**dev:** _Includes non-pulled rewards in the calculation_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node to query |
| holder | address | The address to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | Fair | The staked amount for this holder on this node |

### getTotalInExitQueue

Gets the total amount currently in the exit queue across all users

```solidity
function getTotalInExitQueue() public view returns (Fair amount)
```

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | Fair | The total amount waiting in exit queue |


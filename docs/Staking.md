# Solidity API

## Staking

Manages staking operations for FAIR network nodes

_Implements a two-level fund structure with reward distribution, fee collection, and exit queue management_

### DEFAULT_FEE_RATE

```solidity
uint16 DEFAULT_FEE_RATE
```

Default fee rate starting value (100% of precision, maximum possible fee rate)

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

### rewardWalletReference

```solidity
contract IRewardWallet rewardWalletReference
```

Reference implementation for reward wallets

### totalDisabled

```solidity
Fair totalDisabled
```

Total amount of funds in disabled nodes

### stakeLimit

```solidity
Fair stakeLimit
```

Maximum stake allowed per node

### selfStakeRequirement

```solidity
Fair selfStakeRequirement
```

Minimum self-stake required from node owners

### AllowedReceiverAdded

```solidity
event AllowedReceiverAdded(NodeId node, address receiver)
```

Emitted when an address is added to a node's allowed fee receivers list

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node ID |
| receiver | address | The address added to the allowed receivers list |

### AllowedReceiverRemoved

```solidity
event AllowedReceiverRemoved(NodeId node, address receiver)
```

Emitted when an address is removed from a node's allowed receivers list

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node ID |
| receiver | address | The address removed from the allowed receivers list |

### FeeClaimRequested

```solidity
event FeeClaimRequested(NodeId node, address from, address to, Fair amount)
```

Emitted when a fee claim is requested

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node from which fees are claimed |
| from | address | The address requesting the claim |
| to | address | The address to receive the fees |
| amount | Fair | The amount of fees claimed |

### NodeRewardReceived

```solidity
event NodeRewardReceived(NodeId node, Fair amount)
```

Emitted when a node receives a reward

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node receiving the reward |
| amount | Fair | The amount of the reward |

### RetrieveRequested

```solidity
event RetrieveRequested(address sender, NodeId node, Fair amount)
```

Emitted when a stake retrieval is requested

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| sender | address | The address requesting the retrieval |
| node | NodeId | The node from which stake is being retrieved |
| amount | Fair | The amount being retrieved |

### RewardReceived

```solidity
event RewardReceived(address sender, uint256 amount)
```

Emitted when the contract receives a reward payment

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| sender | address | The address sending the reward |
| amount | uint256 | The amount of the reward |

### RewardWalletCreated

```solidity
event RewardWalletCreated(NodeId node)
```

Emitted when a reward wallet is created for a node

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node for which the reward wallet was created |

### Staked

```solidity
event Staked(address sender, NodeId node, Fair amount)
```

Emitted when stake is added to a node

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| sender | address | The address staking |
| node | NodeId | The node receiving the stake |
| amount | Fair | The amount staked |

### StakedToNewNode

```solidity
event StakedToNewNode(address sender, NodeId node)
```

Emitted when a user stakes to a new node for the first time

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| sender | address | The address staking |
| node | NodeId | The new node receiving stake |

### StoppedStaking

```solidity
event StoppedStaking(address sender, NodeId node)
```

Emitted when a user completely withdraws from a node

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| sender | address | The address that stopped staking |
| node | NodeId | The node from which staking stopped |

### NodeDataRemoved

```solidity
event NodeDataRemoved(NodeId node)
```

Emitted when node data is removed from the contract

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node whose data was removed |

### NodeDisabled

```solidity
event NodeDisabled(NodeId node)
```

Emitted when a node is disabled

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node that was disabled |

### NodeEnabled

```solidity
event NodeEnabled(NodeId node)
```

Emitted when a node is enabled

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node that was enabled |

### RetrievingDelayUpdated

```solidity
event RetrievingDelayUpdated(Timestamp retrievingDelay)
```

Emitted when the retrieving delay is updated

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| retrievingDelay | Timestamp | The new retrieving delay |

### StakeLimitUpdated

```solidity
event StakeLimitUpdated(Fair newLimit)
```

Emitted when the stake limit is updated

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| newLimit | Fair | The new stake limit per node |

### NodeFeeRateUpdated

```solidity
event NodeFeeRateUpdated(NodeId node, uint16 oldFeeRate, uint16 newFeeRate)
```

Emitted when a node's fee rate is updated

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node whose fee rate was updated |
| oldFeeRate | uint16 | The previous fee rate |
| newFeeRate | uint16 | The new fee rate |

### RewardWalletReferenceUpdated

```solidity
event RewardWalletReferenceUpdated(contract IRewardWallet oldReference, contract IRewardWallet newReference)
```

Emitted when the reward wallet reference implementation is updated

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| oldReference | contract IRewardWallet | The previous reference implementation |
| newReference | contract IRewardWallet | The new reference implementation |

### SelfStakeRequirementUpdated

```solidity
event SelfStakeRequirementUpdated(Fair amount)
```

Emitted when the self-stake requirement is updated

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | Fair | The new self-stake requirement |

### SelfStakeProvided

```solidity
event SelfStakeProvided(NodeId nodeId, Fair amount)
```

Emitted when a node owner provides self-stake

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeId | NodeId | The node receiving self-stake |
| amount | Fair | The amount of self-stake provided |

### FeeRateIsIncorrect

```solidity
error FeeRateIsIncorrect(uint16 feeRate)
```

Thrown when the provided fee rate exceeds the maximum allowed

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| feeRate | uint16 | The invalid fee rate that was provided |

### OnlyFeeReductionIsAllowed

```solidity
error OnlyFeeReductionIsAllowed(uint16 currentRate, uint16 newRate)
```

Thrown when attempting to increase the fee rate of nodes with stake (only reduction is allowed)

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| currentRate | uint16 | The current fee rate |
| newRate | uint16 | The attempted new fee rate |

### ZeroAmount

```solidity
error ZeroAmount()
```

Thrown when an operation requires a non-zero amount but zero was provided

### ZeroStakeToNode

```solidity
error ZeroStakeToNode(NodeId node)
```

Thrown when attempting to retrieve from a node where sender has zero stake

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node attempted to retrieve from |

### NodeIsAlreadyDisabled

```solidity
error NodeIsAlreadyDisabled(NodeId node)
```

Thrown when attempting to disable an already disabled node

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node that is already disabled |

### NodeIsNotDisabled

```solidity
error NodeIsNotDisabled(NodeId node)
```

Thrown when attempting an operation that requires an enabled node

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node that is not disabled |

### NotAllowedToClaimRewards

```solidity
error NotAllowedToClaimRewards(address sender)
```

Thrown when an unauthorized address attempts to claim rewards

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| sender | address | The unauthorized address |

### StakeLimitExceeded

```solidity
error StakeLimitExceeded(Fair currentStake, Fair attemptedStake, Fair limit)
```

Thrown when staking/payRewards would exceed the per-node stake limit

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| currentStake | Fair | The current stake on the node |
| attemptedStake | Fair | The amount attempting to be staked |
| limit | Fair | The configured stake limit |

### ReceiverIsAlreadyAllowed

```solidity
error ReceiverIsAlreadyAllowed(address receiver)
```

Thrown when attempting to add an already allowed receiver

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| receiver | address | The receiver that is already allowed |

### ReceiverWasNotAllowed

```solidity
error ReceiverWasNotAllowed(address receiver)
```

Thrown when attempting to remove a receiver that was not in the list of allowed receivers

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| receiver | address | The receiver that was not in the allowed list |

### RewardWalletDoesNotExist

```solidity
error RewardWalletDoesNotExist(NodeId node)
```

Thrown when a Node does not have an associated reward wallet

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node whose reward wallet doesn't exist |

### NodeOwnerCannotRetrieveWhileNodeExists

```solidity
error NodeOwnerCannotRetrieveWhileNodeExists(address nodeOwner, NodeId node)
```

Thrown when a node owner attempts to retrieve stake while their node exists

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nodeOwner | address | The address of the node owner |
| node | NodeId | The existing node |

### InsufficientSelfStake

```solidity
error InsufficientSelfStake(Fair provided, Fair required)
```

Thrown when the provided self-stake is less than the required amount

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

_Ensures that the specified node exists and is active_

### receive

```solidity
receive() external payable
```

Fallback function to receive rewards

_Emits RewardReceived event when ETH is sent to the contract_

### initialize

```solidity
function initialize(address initialAuthority, contract ICommittee committee_, contract INodes nodes_, contract IRewardWallet rewardWalletReference_) external
```

Initializes the Staking contract

_This function is called only once during contract deployment following the proxy pattern_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| initialAuthority | address | The address of the initial access control authority |
| committee_ | contract ICommittee | The address of the Committee contract |
| nodes_ | contract INodes | The address of the Nodes contract |
| rewardWalletReference_ | contract IRewardWallet | The address of the reward wallet reference implementation |

### addAllowedReceiver

```solidity
function addAllowedReceiver(address receiver) external
```

Adds an address to the list of allowed fee receivers for the caller's node

_Only callable by node owners_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| receiver | address | The address to add to the allowed receivers list |

### removeAllowedReceiver

```solidity
function removeAllowedReceiver(address receiver) external
```

Removes an address from the list of allowed fee receivers for the caller's node

_Only callable by node owners_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| receiver | address | The address to remove from the allowed receivers list |

### requestAllFees

```solidity
function requestAllFees(NodeId node) external
```

Requests all earned fees for a specific node

_Only callable by node owners and allowed receivers_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node whose fees to request |

### requestSendAllFees

```solidity
function requestSendAllFees(address payable to) external
```

Requests to send all earned fees to a specified address

_Only callable by node owners
to address must be an allowed receiver if the list is not empty_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| to | address payable | The address to receive the fees |

### setSelfStakeRequirement

```solidity
function setSelfStakeRequirement(Fair amount) external
```

Sets the minimum self-stake requirement for nodes

_Only callable by authorized addresses (restricted)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | Fair | The new self-stake requirement |

### disable

```solidity
function disable(NodeId node) external
```

Disables a node from receiving network rewards and removes it from the active pool

_Only callable by Committee contract (restricted)
Updates committee weight to 0 if the node is active_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node to disable |

### enable

```solidity
function enable(NodeId node) external
```

Enables a previously disabled node, moving its stake back into the active pool

_Only callable by Committee contract (restricted)
Only works on existing (not deleted) active nodes
Updates committee weight after enabling_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node to enable |

### nodeCreated

```solidity
function nodeCreated(NodeId node, address nodeAddress) external payable
```

Called when a new node is created

_Only callable by Nodes contract (restricted)
Deploys a reward wallet if one doesn't exist, sets node as disabled initially
Validates self-stake requirement and stakes all provided initial stake_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The ID of the newly created node |
| nodeAddress | address | The address of the node owner |

### nodeRemoved

```solidity
function nodeRemoved(NodeId node) external
```

Called when a node is removed

_Only callable by Nodes contract (restricted)
Cleans up node data and creates exit requests for node owner's stake and fees
Node must be disabled before removal_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The ID of the node being removed |

### payReward

```solidity
function payReward(NodeId node) external payable
```

Pays a reward to a node

_Only works on existing active nodes
Enforces stake limit unless called from the node's reward wallet
Updates committee weight if node is enabled_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node receiving the reward |

### claimRequest

```solidity
function claimRequest(uint256 requestId) external
```

Claims an exit request and transfers funds to the caller

_Reverts if request is still locked or doesn't belong to caller_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| requestId | uint256 | The ID of the exit request to claim |

### setStakeLimit

```solidity
function setStakeLimit(Fair limit) external
```

Sets the maximum stake allowed per node

_Only callable by authorized addresses (restricted)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| limit | Fair | The new stake limit |

### setRetrievingDelay

```solidity
function setRetrievingDelay(Timestamp delay) external
```

Sets the delay period for exit requests

_Only callable by authorized addresses (restricted)
Even if delay is 0, the request cannot be created and claimed in the same block_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| delay | Timestamp | The new retrieving delay |

### setFeeRate

```solidity
function setFeeRate(uint16 feeRate) external
```

Sets the fee rate for the caller's node

_Only callable by node owners
Fee rate can only be reduced, not increased (except if there are no stakers to the node)
Pulls any pending rewards before updating the rate_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| feeRate | uint16 | The new fee rate (must be <= FEE_RATE_PRECISION) |

### setRewardWalletReference

```solidity
function setRewardWalletReference(contract IRewardWallet rewardWalletReference_) external
```

Updates the reward wallet reference implementation

_Only callable by authorized addresses (restricted)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| rewardWalletReference_ | contract IRewardWallet | The new reward wallet reference implementation |

### requestRetrieveAll

```solidity
function requestRetrieveAll(NodeId node) external
```

Requests to retrieve all stake from a specific node

_Creates an exit request for the caller's entire stake in the node_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node from which to retrieve all stake |

### stake

```solidity
function stake(NodeId node) external payable
```

Stakes to a specific node

_Only works on existing active nodes
msg.value must be greater than 0_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node to stake to |

### getNodeShare

```solidity
function getNodeShare(NodeId node) external view returns (uint256 share)
```

Gets the node's share of the total credits

_Returns 0 if node is disabled
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

```solidity
function getRewardWallet(NodeId node) external view returns (contract IRewardWallet rewardWallet)
```

Gets the reward wallet contract for a specific node

_Reverts if reward wallet doesn't exist_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| rewardWallet | contract IRewardWallet | The reward wallet contract |

### getStakedAmount

```solidity
function getStakedAmount() external view returns (Fair amount)
```

Gets the total amount staked by the caller

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | Fair | The total staked amount |

### getStakedToNodeAmount

```solidity
function getStakedToNodeAmount(NodeId node) external view returns (Fair amount)
```

Gets the amount the caller has staked to a specific node

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | Fair | The staked amount |

### getStakedNodes

```solidity
function getStakedNodes() external view returns (NodeId[] stakedNodes)
```

Gets the list of nodes the caller has stake in

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| stakedNodes | NodeId[] | Array of node IDs |

### getNodeTotalStake

```solidity
function getNodeTotalStake(NodeId node) external view returns (Fair amount)
```

Gets the total stake for a specific node

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | Fair | The total stake on the node |

### getNodeFeeRate

```solidity
function getNodeFeeRate(NodeId node) external view returns (uint16 feeRate)
```

Gets the current fee rate for a specific node

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| feeRate | uint16 | The node's current fee rate |

### getDelegatorsToNode

```solidity
function getDelegatorsToNode(NodeId node) external view returns (address[] delegators)
```

Gets the list of all delegators (stakers) to a specific node

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| delegators | address[] | Array of delegator addresses |

### getDelegatorsToNodeCount

```solidity
function getDelegatorsToNodeCount(NodeId node) external view returns (uint256 count)
```

Gets the number of delegators to a specific node

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| count | uint256 | The number of delegators |

### getExitRequestsCountFor

```solidity
function getExitRequestsCountFor(address user) external view returns (uint256 count)
```

Gets the number of exit requests for a specific user

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| user | address | The user to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| count | uint256 | The number of exit requests |

### getMyTotalInExitQueue

```solidity
function getMyTotalInExitQueue() external view returns (Fair amount)
```

Gets the caller's total amount in the exit queue

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | Fair | The total amount waiting in exit queue |

### getMyExitRequestsCount

```solidity
function getMyExitRequestsCount() external view returns (uint256 count)
```

Gets the number of exit requests for the caller

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| count | uint256 | The number of exit requests |

### isWithinStakeLimit

```solidity
function isWithinStakeLimit(NodeId node) external view returns (bool result)
```

Checks if a node's current stake is within the configured stake limit

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node to check |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | bool | True if within stake limit, false otherwise |

### getExitRequest

```solidity
function getExitRequest(uint256 requestId) external view returns (struct IStaking.ExitRequest request)
```

Gets information about a specific exit request

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| requestId | uint256 | The ID of the exit request |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| request | struct IStaking.ExitRequest | The exit request details |

### getUnlockedExitRequestFor

```solidity
function getUnlockedExitRequestFor(address user, uint256 fromIndex) external view returns (struct IStaking.ExitRequest request)
```

Gets the first unlocked exit request found for a user starting from a specific index

_Does limited iterations to avoid DoS and gas limit issues_

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

```solidity
function getExitRequestAt(address user, uint256 index) external view returns (struct IStaking.ExitRequest request)
```

Gets an exit request at a specific index for a user

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

```solidity
function isRequestUnlocked(uint256 requestId) external view returns (bool unlocked)
```

Checks if an exit request is unlocked and can be claimed

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| requestId | uint256 | The ID of the exit request |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| unlocked | bool | True if the request is unlocked, false otherwise |

### getRetrievingDelay

```solidity
function getRetrievingDelay() external view returns (Timestamp delay)
```

Gets the current retrieving delay

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| delay | Timestamp | The time delay before exit requests can be claimed |

### getTotalInExitQueueFor

```solidity
function getTotalInExitQueueFor(address user) external view returns (Fair amount)
```

Gets the total amount in the exit queue for a specific user

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| user | address | The user to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | Fair | The total amount in exit queue |

### requestRetrieve

```solidity
function requestRetrieve(NodeId node, Fair value) public
```

Requests to retrieve a specific amount of stake from a node

_Creates an exit request and updates committee weight if node is enabled
value must be greater than 0 and less than or equal to caller's stake in the node_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node from which to retrieve stake |
| value | Fair | The amount to retrieve |

### requestFees

```solidity
function requestFees(NodeId node, Fair amount) public
```

Requests a specific amount of fees for a node

_Only callable by allowed receivers or node owner
Creates an exit request for the sender_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node from which to request fees |
| amount | Fair | The amount of fees to request |

### requestSendFees

```solidity
function requestSendFees(address payable to, Fair amount) public
```

Requests to send fees to a specific address

_Only callable by node owners
If allowed receivers are configured, destination must be in the list or be the owner_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| to | address payable | The address to receive the fees |
| amount | Fair | The amount of fees to send |

### isNodeEnabled

```solidity
function isNodeEnabled(NodeId node) public view returns (bool enabled)
```

Checks if a node is currently enabled

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node to check |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| enabled | bool | True if the node is enabled, false otherwise |

### getEarnedFeeAmount

```solidity
function getEarnedFeeAmount(NodeId node) public view returns (Fair amount)
```

Gets the amount of fees earned by a node

_Includes non-pulled rewards from the reward wallet_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The node to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | Fair | The earned fee amount |

### getStakedAmountFor

```solidity
function getStakedAmountFor(address holder) public view returns (Fair amount)
```

Gets the total amount staked by a specific holder across all nodes

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| holder | address | The address to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | Fair | The total staked amount |

### getStakedNodesFor

```solidity
function getStakedNodesFor(address holder) public view returns (NodeId[] stakedNodes)
```

Gets the list of nodes a specific holder has staked to

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| holder | address | The address to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| stakedNodes | NodeId[] | Array of node IDs |

### getStakedToNodeAmountFor

```solidity
function getStakedToNodeAmountFor(NodeId node, address holder) public view returns (Fair amount)
```

Gets the amount a specific holder has staked to a specific node

_Includes non-pulled rewards in the calculation_

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

```solidity
function getTotalInExitQueue() public view returns (Fair amount)
```

Gets the total amount currently in the exit queue across all users

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | Fair | The total amount waiting in exit queue |


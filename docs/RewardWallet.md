# Solidity API

## RewardWallet

Manages reward collection and forwarding for individual FAIR nodes

**dev:** _Receives rewards and forwards them to the Staking contract for the associated node_

### staking

Reference to the Staking contract

```solidity
contract IStaking staking
```

### nodes

Reference to the Nodes contract

```solidity
contract INodes nodes
```

### ownerNode

The node ID that this wallet is associated with

```solidity
NodeId ownerNode
```

### OwnerNodeDoesNotExist

Thrown when attempting an operation that requires the owner node to exist

```solidity
error OwnerNodeDoesNotExist()
```

### ValueExceedsStakeLimit

Thrown when receiving value would exceed the node's stake limit

```solidity
error ValueExceedsStakeLimit()
```

### onlyIfNodeExists

```solidity
modifier onlyIfNodeExists()
```

**dev:** _Ensures that the owner node exists_

### onlyWithinStakeLimit

```solidity
modifier onlyWithinStakeLimit()
```

**dev:** _Ensures that receiving value wouldn't exceed the stake limit_

### receive

Fallback function to receive rewards

```solidity
receive() external payable
```

**dev:** _Automatically flushes rewards to the Staking contract
Only accepts funds if owner node exists and within stake limit_

### initialize

Initializes the RewardWallet contract

```solidity
function initialize(address initialAuthority, contract IStaking staking_, contract INodes nodes_, NodeId ownerNode_) external
```

**dev:** _This function is called only once during contract deployment following the proxy pattern_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| initialAuthority | address | The address of the initial access control authority |
| staking_ | contract IStaking | The address of the Staking contract |
| nodes_ | contract INodes | The address of the Nodes contract |
| ownerNode_ | NodeId | The node ID that this reward wallet is associated with |

### flush

Flushes all accumulated rewards to the Staking contract

```solidity
function flush() public
```

**dev:** _If owner node exists, rewards go to the node via staking.payReward()
If owner node doesn't exist, rewards go to the Staking contract as network rewards (failsafe)_


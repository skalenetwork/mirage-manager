<!-- cspell:ignore permissionless TUPP restaked unstake unstakes Unstaking -->

# FAIR Manager

FAIR-manager smart contracts are a pivotal component in the orchestration and governance of the FAIR network, providing a permissionless and decentralized mechanism for managing the network's operational facets. The project is designed to handle critical functionality such as node operations (registration, deletion, liveliness, etc.), DKG (Distributed Key Generation), committee rotation, and staking — ensuring the scalability, security, and overall efficiency of the network.

## Index

- [Architecture and Components](#architecture-and-components)
  - [Nodes.sol](#nodessol)
  - [Status.sol](#statussol)
  - [DKG.sol](#dkgsol)
  - [Staking.sol](#stakingsol)
  - [Committee.sol](#committeesol)
- [Permission & Control](#permission--control)
- [Custom Libraries & Data Structures](#custom-libraries--data-structures)
  - [RedBlackTree.sol](#redblacktreesol)
  - [TypedSet.sol](#typedsetsol)
  - [TypedMap.sol](#typedmapsol)
  - [Pool.sol](#poolsol)

## Architecture and Components

All main smart contracts use the TUPP (Transparent Upgradeable Proxy Pattern) from OpenZeppelin. Each smart contract has its own ProxyAdmin Contract, Proxy Contract, and Implementation Contract.

All main smart contracts are [AccessManaged](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/master/contracts/access/manager/AccessManagedUpgradeable.sol). Roles are thus centralized in `FairAccessManager.sol`.

### [`Nodes.sol`](./contracts/Nodes.sol)

`Nodes.sol` manages the lifecycle and metadata of nodes within the FAIR network. It provides mechanisms for node registration, removal, and other node-related operations essential for network governance and security.

FAIR supports two types of nodes: Passive and Active Nodes.

- **Active Nodes**: Actively contribute to the functioning and security of the network. The registered owner of an Active Node cannot own any other node (Active or Passive). Active nodes cannot change ownership. Public keys of active nodes will be used to verify blocks, thus these must be available forever, even after node deletion.
- **Passive Nodes**: Do not actively contribute. The owner of a Passive Node can own multiple Passive Nodes. Passive Nodes can freely change ownership.

```solidity
struct Node {
    NodeId id;
    bytes32[2] publicKey;
    bytes ip;
    string domainName;
    address nodeAddress;
    uint16 port;
}
```

#### Invariants

- Node IDs are unique.
- Active Node owners cannot own any other Node, **even if the active node is deleted**.
- Passive Node owners can own multiple Passive Nodes.

#### Data Validation

- IPs must be non-empty and have the size of IPv4 or IPv6.
- Node addresses must correspond to the node's public key (address is computable using the public key).
- Node ports must not be 0.

#### Nodes Main Functions

- `registerNode(address owner, bytes publicKey, ...)`: Registers a new Active Node.
- `registerPassiveNode(address owner, bytes publicKey, ...)`: Registers a new Passive Node.
- `deleteNode(NodeId id)`: Deletes both Active and Passive Nodes.
- `deleteNodeByFoundation(NodeId id)`: Allows DEFAULT_ADMIN to delete both Active and Passive Nodes.
- `setIpAddress(NodeId nodeId, ...)`: Changes the IP address of a Node.
- `setDomainName(NodeId nodeId, ...)`: Changes the domain name of a Node.
- `requestChangeOwner(NodeId nodeId, ...)`: Registers a request to change ownership of a Passive Node.
- `confirmOwnerChange(NodeId nodeId)`: Confirms a request to change ownership of a Passive Node.
- `getNode(NodeId nodeId)`: Retrieves a Node.
- `getNodeId(address nodeAddress)`: Gets the NodeId (if registered and not deleted) for an owner address.
- `getActiveNodeIds()`: Returns a list of IDs of all Active Nodes.
- `getPassiveNodeIds()`: Returns a list of IDs of all Passive Nodes.
- `getPassiveNodeIdsForAddress(address nodeAddress)`: Returns a list of all Passive Node IDs owned by an address.
- `activeNodeExists(NodeId nodeId)`: Returns a boolean stating if a NodeId corresponds to an Active Node.

#### Permissions

- Only node owners can change node details (IP, domain name, etc.).
- Anyone can register a node.
- Only DEFAULT_ADMIN can change the committeeContract address.
- Only node owners can delete a node.
- DEFAULT_ADMIN can delete nodes in V1 of FAIR-manager, but this option may be removed or changed in the future.

#### Nodes Integration Points

- `Nodes.sol` interacts with `Committee.sol` to inform of registration and deletion of Active Nodes.
- `Nodes.sol` interacts with `Status.sol` to inform of deletion of Active Nodes.

### [`Status.sol`](./contracts/Status.sol)

`Status.sol` stores and provides up-to-date information about the liveliness and approved status of Active Nodes in the network.
Nodes that are actively contributing to the network should periodically send a transaction to `Status.sol` to attest that they are **healthy**.
For the first version of FAIR, a whitelist of nodes is maintained. Status stores this whitelist, which effectively limits the nodes allowed to join a Committee.

An active node is considered **healthy** if the last `alive()` transaction was sent less than `Duration public heartbeatInterval` ago.
An active node is considered **eligible** for Committee if it is **healthy**, whitelisted and staked.

#### Status Main Functions

- `alive()`: Allows Active Node owners to prove liveliness.
- `setHeartbeatInterval(Duration interval)`: Allows DEFAULT_ADMIN to set the maximum interval nodes are considered healthy after the last alive transaction.
- `whitelistNode(NodeId nodeId)`: Allows DEFAULT_ADMIN to whitelist a node.
- `nodeRemoved(NodeId node)`: Allows NODES_ROLE to notify of a Node deletion.
- `removeNodeFromWhitelist(NodeId nodeId)`: Allows DEFAULT_ADMIN to remove a node from the whitelist (active or passive).
- `isHealthy(NodeId nodeId)`: Checks if a active node is **healthy**.
- `getWhitelistedNodes()`: Returns the list of all whitelisted nodes.
- `isWhitelisted(NodeId nodeId)`: Returns a boolean stating if a node is whitelisted.

#### Status Integration Points

- `Status.sol` interacts with `Committee.sol` to inform of whitelisted and blacklisted nodes.
- `Status.sol` interacts with `Committee.sol` to notify of every heartbeat sent by a node (node's position is updated in the Node Pool in `Committee.sol`).
- `Status.sol` queries `Nodes.sol` to get node data.

### [`DKG.sol`](./contracts/DKG.sol)

The `DKG` contract implements the Distributed Key Generation protocol for the FAIR network. It coordinates the secure, decentralized generation of cryptographic keys among a committee of nodes, ensuring that no single party controls the resulting key. The contract manages DKG rounds, tracks node participation, and enforces protocol stages.

#### Key Responsibilities

- Orchestrates DKG rounds for each committee, including participant management and round status.
- Handles the broadcast and aggregation of key shares and verification vectors from participating nodes.
- Tracks completion and success of DKG rounds, emitting events for off-chain monitoring.
- Provides access to the generated public key and round data for `Committee.sol` contract.

#### DKG Main Functions

- `generate(NodeId[] participants)`: Starts a new DKG round with the given participants.
- `broadcast(DkgId dkg, G2Point[] verificationVector, KeyShare[] secretKeyContribution)`: Allows a node to broadcast its key share and verification vector during the BROADCAST stage.
- `alright(DkgId dkg)`: Marks a node as having completed all required data submission in the ALRIGHT stage.
- `getParticipants(DkgId dkg)`: Returns the list of nodes participating in a DKG round.
- `getPublicKey(DkgId dkg)`: Returns the generated public key for a successful DKG round.
- `getRound(DkgId dkg)`: Returns all round data for a given DKG round.
- `isNodeBroadcasted(DkgId dkg, NodeId node)`: Checks if a node has broadcasted its data in a round.

#### DKG Integration Points

- Interacts with `Committee.sol` to notify of successful DKG rounds.
- Uses `Nodes.sol` for node identity and ownership verification.

### [`Staking.sol`](./contracts/Staking.sol)

Staking is a core feature of FAIR-manager. To incentivize network participation, Active Nodes that maintain health and eligibility are constantly rewarded, and stakers to these nodes receive a share of the profit proportional to their stake amount. A node's probability to enter a Committee is equal to its percentage of staked tokens.
In FAIR, anyone is allowed to stake to a node and rewards are automatically restaked. Users can unstake their tokens or add stake to a node at any time (i.e., there is no epoch).
Nodes can define their fee up to 100%. Once a fee is set, it can only be decreased.

There are 2 ways to pay rewards:

1. sending funds to `Staking` contract causes the reward distribution across all enabled nodes
2. it's possible to reward delegators of the particular node by calling `payReward` function.
Alternative way is to use Reward wallet. Each node has separate instance of it. Sending funds to it's balance automatically calls the `payReward` function.

It's important for integration with other off-chain components of the system that both ways work correctly when balances of `Staking` or `RewardWallet` are increased without transaction and smart contract execution.

For calculations, we introduce the concept of **Credits**. Each time a user stakes/unstakes FAIR, instead of updating the staked balance, the amount of credits that this user owns is updated. The exchange rate between Credits and FAIR is not fixed and can change over time due to staking rewards.

$$
1 \text{ Credit } = \frac{\text{TotalStakedFAIR}}{\text{TotalNumberOfCredits}} \text{ FAIR}
$$

This means staking rewards are paid and *earned* automatically simply by increasing the `Staking.sol` FAIR balance, and are automatically restaked.

Staking smart contract has a dedicated structure to store Credits of Holders: `Fund`.

```solidity
struct Fund {
    Fair lastBalance;
    Credit totalCredits;
    TypedMap.HolderToCreditMap credits;
    Credit ownerCredits;
    uint16 feeRate; // 0 - 1000‰
}
```

Although the same structure is reused, there are two distinct types of funds:

- The **root fund**: `Fund private _rootFund;` In the root fund, Holders represent Nodes (IDs). There is no feeRate. It is used to track the Credits (share) of each Node. The amount of FAIR staked to a node is equal to the total FAIR balance of `Staking.sol` times the amount of credits it holds, divided by the total amount of credits.

$$
\text{StakedFAIR}\_{Node} = \frac{\text{TotalStakedFAIR}}{\text{TotalNumberOfCredits}\_{rootFund}} \times \text{Credits}\_{Node}
$$

- **Node-specific funds**: For each node, a Fund is created. Each node will have its feeRate, and Holders represent addresses that have staked in this node. Using the same method as above, the amount of FAIR staked by a user to a node can be computed.

$$
\text{StakedFAIR}\_{(Node,User)} = \frac{\text{StakedFAIR}\_{Node}}{\text{TotalNumberOfCredits}\_{NodeFund}} \times \text{Credits}\_{(Node, User)}
$$

Node fees are not *claimed* automatically. Node owners can claim fees at any time, or let them accumulate and compound over time.

As described, Active Nodes can be healthy or unhealthy, depending on whether they actively send `alive()` transactions to `Status.sol`. `Committee.sol` can remove nodes from the Pool, and then set them as *disabled* in `Staking.sol`. A *disabled* node does not receive rewards, but users can still stake or unstake FAIR to them. When a node is *deleted*, it becomes disabled and can never become *enabled* again.

Unstaking and withdrawing fees posts requests to an exit queue. Users must wait for the delay, before their request is available for withdrawal.

#### Staking Main Functions

- `stake(NodeId node)`: Stake FAIR to a node (any user, only existing active nodes, payable).
- `requestRetrieve(NodeId node, Fair value)`: Request to unstake FAIR from a node.
- `claimRequest(uint256 requestId)`: Claim the exit request with the given requestId (if unlocked).
- `disable(NodeId node)`, `enable(NodeId node)`: Disable/enable a node (committee role).
- `nodeCreated(NodeId node)`: Called by `Nodes.sol` when a new node is created.
- `nodeRemoved(NodeId node)`: Called by `Nodes.sol` when a node is deleted.
- `payReward(NodeId node)`: Pays rewards to directly to a Node and it's delegators.
- `addAllowedReceiver(address receiver)`: Add an allowed fee receiver for a node (node owner).
- `removeAllowedReceiver(address receiver)`: Remove an allowed fee receiver for a node (node owner).
- `requestFees(NodeId node, Fair amount)`: Request to claim specific amount of fees for a node.
- `requestAllFees(NodeId node)`: Request to claim all fees for a node.
- `requestSendFees(address payable to, Fair amount)`: Request to send specific amount fees to an address(node owner).
- `requestSendAllFees(address payable to)`: Request to send all fees to an address (node owner).
- `setFeeRate(uint16 feeRate)`: Set node fee rate (only decrease, node owner).
- `setStakeLimit(Fair limit)`: Set max stake limit to each node.
- `setRetrievingDelay(Timestamp delay)`: Set delay for unlocking requests in the exit queue.
- `setRewardWalletReference(IRewardWallet rewardWalletReference_)`: Set reference implementation for reward wallets.

Read functions:
- `getDelegatorsToNode(NodeId node)`: Get delegator addresses for a node.
- `getDelegatorsToNodeCount(NodeId node)`: Get delegator count for a node.
- `getEarnedFeeAmount(NodeId node)`: Get earned fee amount for a node.
- `getExitRequest(uint256 requestId)`: Get exit request data by requestId.
- `getExitRequestAt(address user, uint256 index)`: Get exit request for a user at a specific index.
- `getExitRequestsCountFor(address user)`: Get number of exit requests for a user.
- `getMyExitRequestsCount()`: Get number of exit requests for sender.
- `getMyTotalInExitQueue()`: Get total amount in exit queue for sender.
- `getNodeFeeRate(NodeId node)`: Get node fee rate.
- `getNodeShare(NodeId node)`: Get credits share for a node in root fund.
- `getNodeTotalStake(NodeId node)`: Get total FAIR staked to a node.
- `getRetrievingDelay()`: Get retrieving delay for exit requests.
- `getRewardWallet(NodeId node)`: Get reward wallet address for a node.
- `getStakedAmount()`: Get total staked FAIR for sender.
- `getStakedAmountFor(address holder)`: Get total staked FAIR for a user.
- `getStakedNodes()`: Get list of node IDs staked to by sender.
- `getStakedNodesFor(address holder)`: Get list of node IDs staked to by a user.
- `getStakedToNodeAmount(NodeId node)`: Get amount staked to a node by sender.
- `getStakedToNodeAmountFor(NodeId node, address holder)`: Get amount staked to a node by a user.
- `getTotalInExitQueueFor(address user)`: Get total amount in exit queue for a user.
- `getTotalInExitQueue()`: Get total amount in exit queue (all users).
- `getUnlockedExitRequestFor(address user, uint255 fromIndex)`: Get first found unlocked exit request for a user - starts searching from `fromIndex`, and finish search in the end or after MAX_ITERATIONS requests.
- `isNodeEnabled(NodeId node)`: Returns if node is enabled.
- `isRequestUnlocked(uint256 requestId)`: Returns if a request is unlocked and ready to claim.

#### Stake Limits

FAIR-manager supports setting a maximum stake limit that applies to each nodes to prevent excessive concentration of stake. This feature helps maintain network decentralization and security by limiting the total amount of stake that can be delegated across the network.

#### Staking Integration Points

- `Staking.sol` interacts with `Committee.sol` to update node weights each time an operation that changes the total staking share of a node is performed.
- `Staking.sol` interacts with `RewardWallet.sol` instances to flush rewards that may have been given from consensus layer.
- `Staking.sol` reads data from `Nodes.sol`.

#### Staking Permissions

- Only node owners can change their fee rate.
- Only COMMITTEE_ROLE can change node eligibility.
- Only authorized administrators can set stake limits.
- Only node owners can send earned fees to other users.
- Only authorized participants or node owners can claim fees.
- Only node owners can alter the list of allowed receivers to claim/receive fees.

### [`Committee.sol`](./contracts/Committee.sol)

`Committee.sol` is responsible for maintaining information about past, present, and future Committees.

The Committee smart contract is also the central contract of FAIR-manager, and thus holds the `version` of the project.

It actively maintains a **Pool** of nodes that are eligible to join the next Committee. The contract, using the `Pool.sol` library, is also capable of creating samples of nodes based on their amount of stake to form a Committee.

A Committee is a set of Active Nodes that take part in consensus while the Committee is active, associated with a specific DKG round. After a Committee is created, the DKG round must complete. The successful DKG round with the previously assigned DkgID will include the commonPublicKey and be assigned to the Committee, which will then become a *valid* Committee and be assigned a startingTimestamp.

```solidity
struct Committee {
    NodeId[] nodes;
    DkgId dkg;
    IDkg.G2Point commonPublicKey;
    Timestamp startingTimestamp;
}
```

#### Main Functions

- `ejectUnhealthyNode()`: Selects one of (or the) nodes with the oldest heartbeats and removes it if it is **unhealthy** according to `Status.sol`.
- `select()`: Selects a set of eligible nodes and creates a Committee and DKG round.
- `setCommitteeSize(uint256 size)`: Sets the number of nodes to include in Committees.
- `setRNG(address newRNG)`: Sets the address of the Random Number Generator contract. Details in [RNG](https://docs.skale.space/building-applications/random-number-generation/).
- `disableRNG()`: Sets the address of the Random Number Generator contract to address(0), effectively disabling the use of RNG and using `block.prevrandao` as the source of randomness for committee creation.
- `setMinTransitionDelay`: Sets minimum value of the transition delay that can be set between committee rotations
- `setTransitionDelay(Duration delay)`: Sets the variable transitionDelay. Committee startingTimestamp equals block.timestamp + transitionDelay. This is useful for off-chain components; the delay allows nodes to process and prepare for the new Committee after its creation.
- `setVersion(string calldata newVersion)`: Sets the version of FAIR-manager.
- `isNodeInCurrentOrNextCommittee(NodeId node)`: Returns a boolean indicating if a node is in the current or the next committee.
- `getCommittee(CommitteeIndex committeeIndex)`: Returns a Committee corresponding to a given index, if it exists.

#### Committee Permissions

- Only NODES_ROLE can notify of created and removed nodes.
- Only STATUS_ROLE can notify of whitelisted nodes, blacklisted nodes, and heartbeat signals sent by nodes.
- Only the `IDkg public dkg;` address can notify of a successful DKG round.
- DEFAULT_ADMIN can trigger selection of a new committee.
- Only DEFAULT_ADMIN can change state variables.
- Only STAKING_ROLE can update the weight of nodes in the Pool for weighted-random selection of committee.

#### Integration Points

- `Committee.sol` interacts with `Staking.sol` to communicate changes in the eligibility state of nodes.
- `Committee.sol` queries `Staking.sol` to get up-to-date data about node staking.
- `Committee.sol` interacts with `DKG.sol` to notify of newly created Committees, create DKG rounds, and get DKG round data such as the publicKey of a DKG round.
- `Committee.sol` queries `Status.sol` to get up-to-date data about node liveliness.
- `Committee.sol` may query a skaleRng contract to get random numbers. More info about skale RNG in the [docs](https://docs.skale.space/building-applications/random-number-generation/).

## Permission & Control

`FairAccessManager.sol` is the first smart contract deployed, and DEFAULT_ADMIN_ROLE is given to the deployer account.

The following roles are created:

- `NODES_ROLE`: Assigned to `Nodes.sol` contract
- `STATUS_ROLE`: Assigned to `Status.sol` contract
- `STAKING_ROLE`: Assigned to `Staking.sol` contract
- `COMMITTEE_ROLE`: Assigned to `Committee.sol` contract

All main smart contracts (`Nodes.sol`, `Status.sol`, `Staking.sol`, `Committee.sol`, `DKG.sol`) inherit from `AccessManagedUpgradeable` from OpenZeppelin. Each is initialized with the address of `FairAccessManager.sol`, so access to all **restricted** functions is controlled by `FairAccessManager.sol`.

Although accounts with DEFAULT_ADMIN_ROLE are not automatically granted access to other roles, it is important to note that they have indirect access to all restricted functions. This is because DEFAULT_ADMIN_ROLE holders can add or remove accounts from any other role and manage function selector permissions, effectively giving them ultimate control over contract access management.

## Custom Libraries & Data Structures
### [`ExitQueue.sol`](./contracts/utils/ExitQueue.sol)

The `ExitQueueLibrary` manages delayed withdrawals for staking and rewards. It is used by `Staking.sol` to enforce withdrawal delays and track exit requests per user.

#### Key Data Structures

- **ExitQueue**: Stores all exit requests, user exit data, the total amount in the exit queue, a delay before funds can be claimed, and a counter for request IDs.
- **UserExitData**: Tracks a user's exit request IDs and the total amount pending withdrawal.
- **ExitRequest**: Contains the request ID, user address, node ID, amount, and unlock date for a withdrawal.

#### Main Functions

- `createRequest(queue, user, nodeId, amount)`: Creates a new exit request for a user and node, setting the unlock date based on the configured delay.
- `claim(queue, user, requestId)`: Claims a specific unlocked exit request for a user and removes it from the queue.
- `isRequestUnlocked(queue, requestId)`: Returns whether a specific request is unlocked and ready to be claimed.
- `getNumRequestsForUser(queue, user)`: Returns the number of pending exit requests for a user.
- `getRequest(queue, requestId)`: Returns the details of a specific exit request.
- `getRequestAt(queue, user, index)`: Returns the exit request at a specific index for a user.
- `getUnlockedRequest(queue, user, uint256 fromIndex)`: Returns the first unlocked exit request for a user starting at 'fromIndex' and up to MAX_ITERATIONS iterations.
- `getTotalInQueueForUser(queue, user)`: Returns the total amount pending withdrawal for a user.

#### Configuration

- `retrievingDelay`: Delay (in seconds) before a request can be claimed.

#### Usage

- Used by `Staking.sol` for both stake and fee exit queues, enforcing delays and limits on withdrawals and fee claims.
- Ensures fair and predictable exit mechanics for stakers and node owners.
- Can be reused by other contracts that require the same type of delayed retrieval

### [`RedBlackTree.sol`](./contracts/structs/RedBlackTree.sol)

The `RedBlackTree` library implements a self-adjusting binary search tree for efficient management and weighted selection of nodes, using last alive() call timestamp as implicit keys. It is designed for use in scenarios where fast access, insertion, removal, and weighted random selection are required, such as node pools in committee selection.

The Key of the Nodes in the Red-Black Tree is not explicitly represented, but indirectly represents the liveliness of Nodes.

#### Key Data Structures

- **Node**: Stores the node's `NodeId`, parent, left and right children, color and the total weight of the subtree rooted at this node.

#### RedBlackTree Main Functions

- `insertSmallest`: Inserts a new node as a smallest key.
- `remove`: Removes a node from the tree, maintaining the red-black tree properties.
- `setWeight`: Updates the weight of a node.
- `findByWeight`: Finds the node corresponding to a given cumulative weight (useful for weighted random selection).
- `findLast`: Finds the rightmost node in the tree.
- `getWeight`: Gets weight of the node
- `getWeightTill`: Gets sum of weights of nodes from the leftmost one to included specified one.

#### Usage

- Efficiently supports insertion, removal, and search of nodes in O(log n) time.
- Used in FAIR-manager for managing node pools and committee selection where node weights (e.g., stake) and their liveliness are relevant.

### [`TypedSet.sol`](./contracts/structs/typed/TypedSet.sol)

The `TypedSet` library provides type-safe wrappers around OpenZeppelin's `EnumerableSet` for use with custom types such as `NodeId` and `Holder`. It enables efficient set operations (add, remove, contains, length, values, at) for these types, ensuring type safety and reducing boilerplate in contract code.

- **NodeIdSet**: A enumerable set of `NodeId` values.

These sets are used throughout the FAIR-manager contracts to manage collections of nodes and holders in a type-safe manner.

### [`TypedMap.sol`](./contracts/structs/typed/TypedMap.sol)

The `TypedMap` library provides type-safe wrappers around OpenZeppelin's `EnumerableMap` or standard `map` for mapping between native and domain-specific data of FAIR Manager.

- **AddressToNodeIdMap**: Maps addresses to `NodeId` values.
- **AddressToNodeIdSetMap**: Maps addresses to TypedSets of `NodeId` values.
- **NodeIdToFairMap**: Maps `NodeId` values to `Fair` values.
- **HolderToCreditMap**: Maps `Holder` values to `Credit` values

### [`Pool.sol`](./contracts/utils/Pool.sol)

The `PoolLibrary` provides a robust abstraction for managing a dynamic pool of nodes, supporting efficient weighted random sampling, insertion, removal, and liveliness tracking. It is a core utility for committee selection and node management in FAIR-manager, leveraging the `RedBlackTree` and `TypedSet` libraries for performance and flexibility.

#### Pool Key Data Structures

- **Pool**: Contains a red-black tree (`tree`) for weighted node management, a root node, two sets for present and incoming nodes, and a reference to the `IStatus` contract for liveliness checks.
- **presentNodes**: Set of nodes currently eligible for sampling.
- **incomingNodes**: Set of nodes pending eligibility or recently added.

#### Pool Main Functions

- `add`: Adds a node to the pool's incoming set.
- `moveToFront`: Moves a node to the front (root) of the pool, updating its weight and eligibility.
- `remove`: Removes a node from the pool, updating both the red-black tree and node sets.
- `sample`: Selects a random sample of nodes, weighted by their stake, ensuring only healthy and staked nodes are chosen. Uses the red-black tree for efficient weighted selection.
- `setWeight`: Updates the weight of a node in the pool, affecting its selection probability.
- `getOldestIsh`: Returns the *oldest-ish* node (by red-black tree order), useful for ejection or rotation logic. Last nodes are more likely to be unhealthy.
- `contains`: Checks if a node is present in either the present or incoming sets.
- `length`: Returns the total number of nodes in the pool.

#### Internal Logic

- `_findLastHealthyNode`: Finds the rightmost healthy node in the red-black tree.

#### Pool Usage

- Enables efficient, fair, and secure committee selection by supporting weighted random sampling and dynamic pool updates.
- Integrates with `Status.sol` to ensure only healthy nodes are considered for selection.
- Used by `Committee.sol` to manage node eligibility and rotation.

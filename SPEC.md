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
  - [ExitQueue.sol](#exitqueuesol)
  - [RedBlackTree.sol](#redblacktreesol)
  - [TypedSet.sol](#typedsetsol)
  - [TypedMap.sol](#typedmapsol)
  - [Pool.sol](#poolsol)

## API Documentation

For detailed API documentation of all contracts, functions, events, and errors, see the [auto-generated documentation](./docs/):

- [Committee.sol API](./docs/Committee.md)
- [DKG.sol API](./docs/DKG.md)
- [FairAccessManager.sol API](./docs/FairAccessManager.md)
- [Nodes.sol API](./docs/Nodes.md)
- [RewardWallet.sol API](./docs/RewardWallet.md)
- [Staking.sol API](./docs/Staking.md)
- [Status.sol API](./docs/Status.md)

> **Note**: The API documentation is automatically generated from NatSpec comments and validated by CI/CD. See [docs/README.md](./docs/README.md) for more information.

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

#### API Reference

For complete function signatures, parameters, and return values, see [Nodes.sol API Documentation](./docs/Nodes.md).

**Key functions include**:
- Node registration (Active and Passive)
- Node deletion
- Ownership management (for Passive nodes)
- Node metadata updates (IP, domain name)
- Node queries and lookups

#### Permissions

- Only node owners can change node details (IP, domain name, etc.).
- Anyone can register a node.
- Only DEFAULT_ADMIN can change the committeeContract address.
- Only node owners can delete a node.
- DEFAULT_ADMIN can delete nodes in V1 of FAIR-manager, but this option may be removed or changed in the future.

#### Nodes Integration Points

- `Nodes.sol` interacts with `Committee.sol` to inform deletion of Active Nodes.
- `Nodes.sol` interacts with `Status.sol` to inform of deletion of Active Nodes.
- `Nodes.sol` interacts with `Staking.sol` to inform of registration and deletion of Active Nodes.
- `Nodes.sol` forwards self-stake payments to `Staking.sol` during node registration.

### [`Status.sol`](./contracts/Status.sol)

`Status.sol` stores and provides up-to-date information about the liveliness and approved status of Active Nodes in the network.
Nodes that are actively contributing to the network should periodically send a transaction to `Status.sol` to attest that they are **healthy**.
For the first version of FAIR, a whitelist of nodes is maintained. Status stores this whitelist, which effectively limits the nodes allowed to join a Committee.

An active node is considered **healthy** if the last `alive()` transaction was sent less than `Duration public heartbeatInterval` ago.
An active node is considered **eligible** for Committee if it is **healthy**, whitelisted and staked.

#### API Reference

For complete function signatures, parameters, and return values, see [Status.sol API Documentation](./docs/Status.md).

**Key functions include**:
- Heartbeat submission (`alive()`)
- Node whitelisting management
- Health status checking
- Heartbeat interval configuration

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

#### API Reference

For complete function signatures, parameters, and return values, see [DKG.sol API Documentation](./docs/DKG.md).

**Key functions include**:
- DKG round initialization
- Key share broadcasting
- Completion verification
- DKG round info retrieval

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

#### API Reference

For complete function signatures, parameters, and return values, see [Staking.sol API Documentation](./docs/Staking.md).

**Key operations include**:
- Staking and unstaking operations
- Exit queue management
- Fee claiming/sending and distribution
- Node enabling/disabling
- Reward distribution

#### Stake Limits

FAIR-manager supports setting a maximum stake limit that applies to each nodes to prevent excessive concentration of stake. This feature helps maintain network decentralization and security by limiting the total amount of stake that can be delegated across the network.

#### Self-Stake Requirement

FAIR-manager supports a configurable self-stake requirement for Active Node registration. This feature ensures that node operators have a financial commitment to the network's health and security.

**Key Features:**
- **Global Parameter**: `selfStakeRequirement` is a network-wide parameter that can be set by DEFAULT_ADMIN.
- **Required on Registration**: When registering an Active Node, if `selfStakeRequirement > 0`, the node owner must provide at least that amount of FAIR tokens as stake.
- **Automatic Staking**: The provided self-stake is automatically forwarded to the Staking contract and staked to the newly created node.
- **Retrieval Restrictions**: Node owners cannot retrieve their self-stake while their node exists - this prevents operators from withdrawing their commitment while still operating a node.
- **Automatic Return on Deletion**: When a node is deleted (either by the owner or foundation), the node owner's stake and any earned fees are automatically made available for withdrawal through the exit queue.


#### Staking Integration Points

- `Staking.sol` interacts with `Committee.sol` to update node weights each time an operation that changes the total staking share of a node is performed.
- `Staking.sol` interacts with `RewardWallet.sol` instances to flush rewards that may have been given from consensus layer.
- `Staking.sol` reads data from `Nodes.sol`.
- `Staking.sol` receives self-stake payments from `Nodes.sol` during node registration.

#### Staking Permissions

- Only node owners can change their fee rate.
- Only COMMITTEE_ROLE can change node eligibility.
- Only authorized administrators can set stake limits.
- Only authorized administrators can set the self-stake requirement.
- Only node owners can send earned fees to other users.
- Only authorized participants or node owners can claim fees.
- Only node owners can alter the list of allowed receivers to claim/receive fees.
- Node owners cannot retrieve their stake while their node exists.

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

#### API Reference

For complete function signatures, parameters, and return values, see [Committee.sol API Documentation](./docs/Committee.md).

**Key operations include**:
- Committee selection and formation
- Node pool management
- Unhealthy node ejection
- Committee size and delay configuration
- Random number generator management
- Version management

#### Committee Permissions

- Only NODES_ROLE can notify of removed nodes.
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

For details on role constants and initialization, see [FairAccessManager.sol API Documentation](./docs/FairAccessManager.md).

## Custom Libraries & Data Structures

### [`ExitQueue.sol`](./contracts/utils/ExitQueue.sol)

The `ExitQueueLibrary` manages delayed withdrawals for staking and rewards. It is used by `Staking.sol` to enforce withdrawal delays and track exit requests per user.

#### Key Concepts

- **Exit Requests**: Structured records of withdrawal requests with unlock timestamps
- **User Tracking**: Per-user tracking of pending exit requests and total amounts in queue
- **Delayed Retrieval**: Configurable delay before funds can be claimed
- **Queue Management**: Efficient creation, claiming, and querying of exit requests

The library ensures fair and predictable exit mechanics for stakers and node owners. It could be reused by other contracts requiring delayed retrieval functionality.

For implementation details, see the source code at [`contracts/utils/ExitQueue.sol`](./contracts/utils/ExitQueue.sol).

### [`RedBlackTree.sol`](./contracts/structs/RedBlackTree.sol)

The `RedBlackTree` library implements a self-balancing binary search tree for efficient management and weighted selection of nodes, using last `alive()` call timestamp as implicit keys. It provides O(log n) complexity for insertion, removal, and search operations.

#### Key Features

- Self-balancing red-black tree structure
- Weight tracking for subtrees (enables weighted random selection)
- Liveliness-based ordering (implicit keys based on heartbeat timestamps)
- Efficient cumulative weight queries

Used in FAIR-manager for managing node pools and committee selection where node weights (stake) and liveliness are critical factors.

For implementation details, see [`contracts/structs/RedBlackTree.sol`](./contracts/structs/RedBlackTree.sol).

### [`TypedSet.sol`](./contracts/structs/typed/TypedSet.sol)

The `TypedSet` library provides type-safe wrappers around OpenZeppelin's `EnumerableSet` for use with custom types such as `NodeId`. It enables efficient set operations while ensuring type safety and reducing boilerplate.

**Available types**: `NodeIdSet`

For implementation details, see [`contracts/structs/typed/TypedSet.sol`](./contracts/structs/typed/TypedSet.sol).

### [`TypedMap.sol`](./contracts/structs/typed/TypedMap.sol)

The `TypedMap` library provides type-safe wrappers around OpenZeppelin's `EnumerableMap` and standard mappings for domain-specific data types in FAIR Manager.

**Available types**: `AddressToNodeIdMap`, `AddressToNodeIdSetMap`, `NodeIdToFairMap`, `HolderToCreditMap`

For implementation details, see [`contracts/structs/typed/TypedMap.sol`](./contracts/structs/typed/TypedMap.sol).

### [`Pool.sol`](./contracts/utils/Pool.sol)

The `PoolLibrary` provides a robust abstraction for managing a dynamic pool of nodes, supporting efficient weighted random sampling, insertion, removal, and liveliness tracking. It is a core utility for committee selection and node management in FAIR-manager.

#### Key Concepts

- **Present Nodes**: Currently eligible nodes for sampling
- **Incoming Nodes**: Nodes pending eligibility or recently added
- **Weighted Sampling**: Random selection weighted by node stake
- **Health Tracking**: Integration with `Status.sol` for liveliness checks
- **Red-Black Tree**: Efficient weighted selection using the `RedBlackTree` library

The Pool enables fair and secure committee selection by supporting weighted random sampling, dynamic pool updates, and automatic health checking. Used by `Committee.sol` for node eligibility and rotation management.

For implementation details, see [`contracts/utils/Pool.sol`](./contracts/utils/Pool.sol).
